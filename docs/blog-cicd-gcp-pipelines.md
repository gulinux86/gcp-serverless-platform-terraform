---
title: "Shipping Serverless Infrastructure on GCP with Terraform: Five Pipelines and the Trade-offs Behind Them"
subtitle: "A keyless, two-layer GitHub Actions delivery model for Cloud Run — and the engineering decisions (and mistakes) that shaped it."
tags: [Terraform, GCP, GitHubActions, DevOps, Serverless, CICD]
---

# Shipping Serverless Infrastructure on GCP with Terraform: Five Pipelines and the Trade-offs Behind Them

> **Part 1 of 2** on building a keyless, two-layer Terraform delivery model on GCP. Part 2 goes under the hood: [Terraform State Topology: Designing Module and Environment Boundaries That Scale]([Part 2 link]).

Most "Terraform CI/CD" articles show you a happy-path `plan` and `apply` and call it a day. Real delivery is messier: how do you authenticate without long-lived keys, keep `prod` from being one click away, give reviewers a readable diff, and tear everything down without GCP fighting you on the way out?

This is a walkthrough of a production-shaped delivery pipeline for a serverless GCP stack (Cloud Run + Cloud SQL + a global HTTPS load balancer, all provisioned with Terraform). I'll go pipeline by pipeline — but the real value is in the **trade-offs**: the decisions where there was no obviously right answer, and a few where I got it wrong before I got it right.

---

## The shape of the system

The platform is two Terraform layers, each an **independent root module with its own remote state**:

```
foundation/   →  VPC, subnets, Serverless VPC Access Connector, PSA peering, firewall
                 └── GCS state: gs://<bucket>/<env>/foundation/
workload/     →  Cloud Run, Cloud SQL, Load Balancer, Cloud Armor, secrets, IAM
                 └── GCS state: gs://<bucket>/<env>/workload/
                 reads foundation's outputs via terraform_remote_state
```

On top of it, five GitHub Actions workflows:

| Workflow | Trigger | Job |
|---|---|---|
| `terraform-test` | PR | Module unit tests (mocked providers, no cloud) |
| `security-scan` | PR | Trivy IaC scan, fails on HIGH/CRITICAL |
| `terraform-plan` | PR + manual | Per-layer plan, posted as a PR comment |
| `terraform-deploy` | manual | Gated apply of a saved plan |
| `terraform-destroy` | manual | Confirmed, reverse-order teardown |

Everything that touches GCP authenticates through **Workload Identity Federation** — there are no service-account JSON keys anywhere in the repo or in GitHub.

---

## Trade-off #1: Two independent layers vs. one root module

The single most consequential decision was splitting the stack into two roots instead of one.

**One root** is simpler: a single `terraform apply` builds the world, and the module graph enforces ordering automatically. But every change — even a one-line tweak to a Cloud Run env var — re-plans the entire VPC, and a `destroy` is all-or-nothing.

**Two roots** trade that simplicity for a smaller blast radius. `workload` reads `foundation`'s outputs from its remote state rather than receiving them as inputs:

```hcl
# workload/remote_state.tf
data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "${var.environment}/foundation" }
}

# workload/main.tf
locals {
  vpc_network_id   = data.terraform_remote_state.foundation.outputs.vpc_network_id
  vpc_connector_id = data.terraform_remote_state.foundation.outputs.vpc_connector_id
}
```

| | One root | Two roots |
|---|---|---|
| Day-to-day deploy | Re-plans everything | Apply `workload` only |
| Blast radius | Whole stack | Per layer |
| Ordering | Implicit (graph) | Explicit (pipeline + remote state) |
| Cognitive load | Lower | Higher |

The cost of two roots is that "apply `foundation` before `workload`" is no longer enforced by Terraform — it's a contract the **pipeline** has to uphold. That contract shows up everywhere below: deploy applies `foundation → workload`, destroy reverses it, and plan refuses to plan `workload` if `foundation` hasn't been applied yet.

---

## Trade-off #2: Keyless auth (Workload Identity Federation)

The classic mistake is dropping a service-account JSON key into a GitHub secret. It works, it never expires, and it's a liability forever.

Workload Identity Federation (WIF) lets GitHub's OIDC token be exchanged for short-lived GCP credentials — no static key. The bootstrap (run once, by a human, with elevated credentials) creates a pool, a provider scoped to *exactly one repository*, and a deployer service account:

```hcl
resource "google_iam_workload_identity_pool_provider" "github" {
  # ...
  attribute_condition = "assertion.repository == '${var.github_repo}'"
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
```

The trade-off is **setup complexity**: WIF has more moving parts than a key (pool, provider, attribute mapping, an impersonation binding), and it's the kind of thing you set up once and then forget how it works. But it removes an entire class of credential-leak incidents, and it's per-environment, so a compromised `hml` provider can never mint `prod` tokens. That's a trade worth making every time.

---

## The pipelines, and why each is shaped the way it is

### `terraform-test` — fast, credential-free feedback

Module tests use Terraform's native test framework with **mocked providers** (`mock_provider` + `command = plan`). No GCP credentials, no real infrastructure, runs on every PR including from forks:

```hcl
mock_provider "google" {}

run "no_vpc_access_without_connector" {
  command = plan
  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].vpc_access) == 0
    error_message = "No vpc_access block must render when no connector is provided."
  }
}
```

These tests catch the silent killers: a broken `count`/`for_each` ternary that produces *zero* resources without erroring. A reviewer can't see that in a diff; a test can.

> **Trade-off:** mocked tests validate *structure and logic*, not real cloud behavior. They'll never catch a quota error or an IAM gap. They're a fast first gate, not a substitute for a real plan.

### `security-scan` — a Trivy gate that fails closed

Trivy runs in `config` mode over the Terraform, uploads SARIF to the Security tab, and **fails the PR on HIGH/CRITICAL**. Exceptions live in a committed `.trivyignore`, each with a written justification.

The first run immediately earned its keep: `AVD-GCP-0015 — Database instance does not require TLS`. That's not a finding to suppress; it's a finding to fix:

```hcl
ip_configuration {
  ipv4_enabled = false
  ssl_mode     = "ENCRYPTED_ONLY"   # require TLS in transit
}
```

> **Trade-off:** a fail-closed gate occasionally blocks a legitimate PR over a debatable rule. The `.trivyignore`-with-justification policy keeps the gate honest without letting it become a rubber stamp.

### `terraform-plan` — read-only feedback that doesn't block on missing infra

Plan posts the diff as a PR comment so changes are reviewed before they're applied. The interesting design problem: a real plan needs cloud auth and a populated backend, but you don't want the PR to go red just because WIF isn't wired up yet, or because someone opened a docs PR.

So the plan workflow **always** runs `fmt` and a credential-free `validate`, and only attempts the real plan when WIF is configured — otherwise it skips with an explanatory comment instead of failing:

```bash
if [ -z "$WIF_PROVIDER" ]; then
  terraform -chdir="$LAYER" init -backend=false
  terraform -chdir="$LAYER" validate     # still real feedback
  echo "Plan skipped — WIF not configured for ${ENV}."
  exit 0
fi
```

It also guards the cross-layer dependency: before planning `workload`, it checks whether `foundation`'s state actually has outputs, and skips with "apply foundation first" rather than spilling a raw `terraform_remote_state` error.

> **Trade-off:** a "skipped" check is a green check. You're trading strict gating for developer flow — acceptable for plan (it's advisory), unacceptable for the apply gate.

### `terraform-deploy` — manual, gated, and saved-plan only

Nothing applies on merge. Deploy is a manual dispatch where you pick the environment and the layer (`foundation`, `workload`, or `both`). The day-to-day case is a `workload`-only apply that never touches the network.

Two gates run before any apply — the module tests and the Trivy scan — and `prod` is tied to a GitHub Environment with a required reviewer, so a prod run *pauses for approval*. The apply always uses a saved plan (`plan -out` then `apply tfplan`), never a re-plan at apply time.

```yaml
on:
  workflow_dispatch:
    inputs:
      environment: { type: choice, options: [hml, prod] }
      layer:       { type: choice, options: [foundation, workload, both] }
```

> **Trade-off:** manual deploys are slower than push-to-deploy. For infrastructure — where a bad apply can delete a database — that friction is a feature, not a bug.

### `terraform-destroy` — confirmed and reverse-ordered

Destroy is the most dangerous button in the repo, so it carries the most guardrails: a typed confirmation that must match the environment name, the same `prod` reviewer gate, and reverse ordering (`workload` before `foundation`). It shares a concurrency group with deploy so a teardown can never overlap an apply for the same environment.

```bash
if [ "$confirm" != "$ENVIRONMENT" ]; then
  echo "Confirmation does not match environment. Aborting."; exit 1
fi
```

---

## The trade-offs that actually bit me

The decisions above were deliberate. These were learned the hard way.

### Direct VPC Egress vs. the VPC Access Connector

Cloud Run originally reached the VPC through **Direct VPC Egress** (`vpc_access.network_interfaces.subnetwork`). It's cheaper and higher-throughput — and it quietly reserves IP addresses *inside your application subnet*. GCP doesn't release those reservations promptly on teardown; it holds them for up to ~120 minutes, which means `terraform destroy` fails trying to delete a subnet that's "still in use."

The original code papered over this with a small forest of `time_sleep` guards and a decommission-signal handshake between layers. It worked, but it was fragile and slow.

Switching to a **Serverless VPC Access Connector** removed the root cause. The connector is a managed resource on its own dedicated `/28`, so deleting Cloud Run strands nothing in the app subnet — and all those teardown guards simply disappeared.

| | Direct VPC Egress | VPC Access Connector |
|---|---|---|
| Cost | Lower | Always-on instances |
| Throughput | Higher | Capped |
| Teardown | IP-release waits, fragile | Clean, managed delete |

> **Lesson:** the cheaper networking primitive carried a hidden operational tax at *destroy* time. For a stack that's created and destroyed often, predictable teardown was worth more than peak throughput.

### PSA vs. PSC for Cloud SQL

The remaining teardown wait is **Private Service Access (PSA)** — the VPC peering that gives Cloud SQL a private IP. PSA holds an internal lock for several minutes after subnet deletion; the config absorbs it with `deletion_policy = "ABANDON"` and a 10-minute buffer. **Private Service Connect (PSC)** avoids the peering entirely and tears down cleanly — but adds a per-instance endpoint and DNS to manage. For a single VPC with one database, PSA's simplicity still wins; at multi-VPC scale, PSC would.

### Native `terraform test` is version-sensitive

A module test passed locally and failed in CI. Same code, different Terraform version. The culprit was indexing a `set` block inside a `for`-comprehension's `if` condition:

```hcl
# fails on the rules that have no rate_limit_options
if rule.action == "throttle" && rule.rate_limit_options[0]...

# robust across versions
if try(rule.rate_limit_options[0].rate_limit_threshold[0].count, null) == 50
```

> **Lesson:** pin your local Terraform to the CI version. "Works on my machine" is a real failure mode for `terraform test`, where evaluation semantics shifted between minor releases.

### The `.gitignore` that ate my variables

The standard Terraform `.gitignore` ignores `*.tfvars` — sensible, since tfvars often hold secrets. But my per-environment tfvars held only *non-secret* config (resource name prefix, region). They were silently never committed, and `terraform-deploy` died with "variables file does not exist" only after a clean `init`. The fix was a scoped negation:

```gitignore
*.tfvars
!**/environments/*/terraform.tfvars   # non-secret config; secrets go via TF_VAR_*
```

> **Lesson:** "secrets via `TF_VAR_*`, config in committed tfvars" is a clean split — but the boilerplate `.gitignore` assumes all tfvars are secret. Audit it.

### Is `project_id` a secret?

A GCP project ID isn't a credential, but for a public portfolio repo I didn't want it committed. The pragmatic answer: inject it as `TF_VAR_project_id` from a GitHub secret, keep only non-identifying values in tfvars, and give the state bucket a fixed name (`serverless-hml`) instead of one derived from the project ID.

> **Honest caveat:** treating `project_id` as a secret keeps it out of the repo and out of step logs — but `terraform plan` output (posted as a PR comment) still contains it in resource paths, and GitHub doesn't mask secrets in API-created comments. "Secret" here means "not committed," not "never visible."

### `editor` vs. least privilege

The deployer SA carries `roles/editor` plus `iam.securityAdmin`. It's coarse — the opposite of the per-resource least-privilege the *application* identities use. The justification is honest: `editor` + `securityAdmin` covers the two things that usually break serverless applies — `iam.serviceAccounts.actAs` (Cloud Run running *as* a service account) and `*.setIamPolicy` (the dozens of fine-grained bindings) — without a whack-a-mole of denied permissions. Tightening it to a curated role list is a known, deferred follow-up.

> **Lesson:** least privilege for *workload* identities is non-negotiable. For the *deployer*, there's a real velocity-vs-privilege trade-off, and being explicit about the debt beats pretending it isn't there.

---

## Takeaways

- **Push the dependency contract into the pipeline.** Two independent layers buy a smaller blast radius, but only if deploy/destroy/plan all honor the ordering the module graph used to enforce.
- **Keyless beats convenient.** Workload Identity Federation is more setup than a JSON key, and it's the right default every time.
- **Gates should fail closed; feedback should fail open.** The apply gate blocks on real failures; the plan check skips gracefully when infra isn't wired up yet.
- **The cheap primitive can carry a hidden tax.** Direct VPC Egress was cheaper to run and far more expensive to destroy.
- **Name your debts.** The `editor` role and PSA's teardown buffer are deliberate, documented trade-offs — not accidents.

The full stack — two layers, five pipelines, keyless auth, and a connector-based networking model — deploys `hml` end-to-end and tears down cleanly on the first pass. The interesting part was never the YAML. It was every place I had to choose what to optimize for.

**Next:** the pipelines lean on a deliberate state topology — two independent layers across two environments. Part 2 unpacks that design, the alternatives I rejected (workspaces, Terragrunt), and when it's the *wrong* choice → [Terraform State Topology: Designing Module and Environment Boundaries That Scale]([Part 2 link]).

---

*Part 1 of 2. Built with Terraform, Cloud Run, and GitHub Actions on Google Cloud. Feedback and war stories welcome.*
