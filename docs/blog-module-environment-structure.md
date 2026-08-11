---
title: "Terraform State Topology: Module and Environment Boundaries"
subtitle: "Refactoring a GCP serverless stack from a single root into independent layers and per-environment state — what was built, why this structure, and the trade-offs."
tags: [Terraform, GCP, InfrastructureAsCode, Platform Engineering, DevOps]
---

# Terraform State Topology: Module and Environment Boundaries

> **Part 2 of 2.** Part 1 covers the delivery pipelines on top of this structure: [Shipping Serverless Infrastructure on GCP with Terraform]([Part 1 link]).

Every `terraform apply` operates on a single state file. That file is the atomic unit of blast radius, locking, and plan time. Module structure is organization; **state topology is architecture.** This is how a serverless GCP platform was refactored from one root into **two independent layers across two environments** — a 2×2 grid of state files — and why.

---

## What was built

Two layers, separated by lifecycle. Each is an independent Terraform root with its own backend and state.

| Layer | Module | Key resources |
|---|---|---|
| **foundation** (slow lifecycle) | `vpc` | `google_compute_network`, `google_compute_subnetwork`, `google_vpc_access_connector` (Serverless VPC Access), `google_service_networking_connection` (PSA / private Cloud SQL) |
| | `cloud_firewall` | `google_compute_firewall` |
| **workload** (fast lifecycle) | `cloud_run_service` | `google_cloud_run_v2_service`, `google_cloud_run_v2_job`, run IAM members |
| | `cloud_sql` | `google_sql_database_instance` (private IP), `google_sql_database`, `google_sql_user` |
| | `https_load_balancer` | `google_compute_global_address`, `backend_service`, `url_map`, `target_https_proxy` + `target_http_proxy`, `global_forwarding_rule`, `managed_ssl_certificate`, serverless `region_network_endpoint_group` |
| | `cloud_armor` | `google_compute_security_policy` (WAF / rate limiting on the LB) |
| | `artifact_registry` | `google_artifact_registry_repository` (container images) |
| | `secret_manager` + `secret_rotation` | `google_secret_manager_secret`/`version`, `logging_project_sink`, `pubsub_topic`/`subscription`, `monitoring_alert_policy` (rotation signal) |
| | `pubsub` | `google_pubsub_topic`/`subscription` (app messaging) |
| | `cloud_storage` | `google_storage_bucket` + IAM |
| | `iam_service_account` | `google_service_account` + bindings (per-service least privilege) |

A separate `bootstrap` root provisions the keyless CI seam — `google_iam_workload_identity_pool` + `provider` for GitHub Actions OIDC — so no service-account keys live in the repo.

---

## Why this structure

**Separate along lifecycle, not along diagrams.** Networking changes rarely and is shared; application compute changes on every deploy. Putting them in one state means a one-line Cloud Run change re-plans the VPC, Cloud SQL, and the load balancer, holds the lock on the whole stack, and makes `destroy` all-or-nothing. Splitting them makes the **blast radius match the change**.

**Two orthogonal axes:**

```
                  ┌──────────────────┬──────────────────┐
                  │      hml         │       prod       │
   ┌──────────────┼──────────────────┼──────────────────┤
   │ foundation   │ <bucket>/hml/    │ <bucket>/prod/   │
   │ (networking) │   foundation     │   foundation     │
   ├──────────────┼──────────────────┼──────────────────┤
   │ workload     │ <bucket>/hml/    │ <bucket>/prod/   │
   │ (app + data) │   workload       │   workload       │
   └──────────────┴──────────────────┴──────────────────┘
        layer axis  ───────────────▶   environment axis
```

- **Layer axis** — *what changes together vs. independently.*
- **Environment axis** — *the same code against isolated copies of the world.*

Conflating them is a common mistake; they are handled with different mechanisms.

---

## Cross-layer dependency: remote state, not a root

With no orchestrator, `workload` learns the VPC/connector IDs by reading `foundation`'s state:

```hcl
# workload/remote_state.tf
data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "${var.environment}/foundation" }
}

locals {
  vpc_network_id   = data.terraform_remote_state.foundation.outputs.vpc_network_id
  vpc_connector_id = data.terraform_remote_state.foundation.outputs.vpc_connector_id
  vpc_peering_id   = data.terraform_remote_state.foundation.outputs.psa_connection_id
}
```

Chosen over a shared root (tight coupling) and over data-source rediscovery (re-queries the API on every plan, needs read IAM). Remote state makes the dependency **explicit, directional, and free at plan time**.

**Senior consequence:** `foundation`'s `outputs` block is now a **public API**. Renaming `vpc_connector_id` breaks `workload` at plan time in a different state. The coupling did not disappear — it moved from the module graph into a versioned output contract and an ordering rule the pipeline must enforce (apply `foundation` first, reverse on destroy).

---

## Environments: directories + partial backends (not workspaces)

Each layer carries per-environment **configuration, not code**:

```
foundation/environments/
  hml/   { backend.hcl, terraform.tfvars }
  prod/  { backend.hcl, terraform.tfvars }
```

```hcl
# version.tf — partial backend, completed at init
terraform { backend "gcs" {} }
```
```bash
terraform -chdir=foundation init -backend-config=environments/hml/backend.hcl
```

**Not workspaces:** they switch state via a hidden CLI pointer (invisible "which env am I applying to?") and force every environment to share one configuration. **Not Terragrunt (yet):** DRY across environments also couples them; for 2 envs × 2 layers the duplication is a few `backend.hcl`/`tfvars` files — readable and independently editable. Terragrunt earns its place when env × layer count makes that painful.

**Three-way split** that makes the same modules promotable unchanged:

- **Code** (`.tf`, `modules/`) — environment-agnostic; never names a project or secret.
- **Config** (`backend.hcl`, `tfvars`) — committed, non-secret: prefix, region, state bucket, env label.
- **Secrets** (`project_id`, DB password, keys) — injected at runtime via `TF_VAR_*` from CI; never committed.

> Caveat: the stock `.gitignore` ignores `*.tfvars`. Once secrets live in `TF_VAR_*`, tfvars are *config* and must be committed — add a scoped exception or CI runners won't find them.

Promotion `hml` → `prod` is the same code, a different backend + var-file. `prod` differs only in configuration and governance (protected environment, required reviewer).

---

## Trade-offs

| Decision | Advantage | Cost |
|---|---|---|
| Independent layers vs. one root | Per-layer blast radius; deploy `workload` without touching networking | Ordering is an operational contract, not a graph guarantee |
| Remote-state handshake vs. root inputs / data sources | Explicit, directional, free-at-plan dependency | Outputs become a public API; eventual consistency; producer must exist first |
| Directories vs. workspaces | Environment explicit; envs can diverge | Per-env config duplication |
| Directories vs. Terragrunt | Readable, independently editable | Duplication grows with env × layer count |
| Config/secret split | Same code promotes unchanged; no secrets in repo | `.gitignore` and CI plumbing need care |
| Partial backends | One codebase, many states | Easy to init the wrong env if scripted carelessly |

---

## When this design is wrong

- **Small, short-lived systems** — a single root is less to reason about.
- **Layers that genuinely share a lifecycle** — separation only adds an ordering contract for no gain.
- **Many environments × many layers** — hand-managed directories become the duplication problem Terragrunt solves.
- **Teams that treat cross-layer outputs casually** — without output discipline you trade a compile-time error for a runtime, cross-state surprise.

Two-layer-by-two-env is a sweet spot, not a universal law. The refactor didn't make the system smaller — it made the **blast radius match the change**.

---

## What you gain

Consolidated, what this structure delivers in practice:

- **Isolated blast radius.** A `workload` change never touches — or re-plans — the VPC, Cloud SQL, or load balancer. Each `apply`'s reach is the size of the layer, not the whole platform.
- **Faster plan and apply.** Each state holds only its layer's resources, so `plan` reads and diffs a smaller graph. *(Measured: foundation `<X>s` → workload `<Y>s`, vs. `<Z>s` for the single root.)*
- **Independent deploys per layer.** You can ship the application dozens of times a day without touching networking, which stays stable for weeks.
- **Per-layer locking.** The state lock is held per layer, not for the whole stack — no contention between an app deploy and a networking change running in parallel in CI.
- **Promotion without a branch or merge.** `hml` → `prod` is the same code with a different backend and var-file; the difference is configuration and governance, not code. No more "works in hml, breaks in prod" from code drift.
- **Surgical destroy.** You can destroy and recreate a single layer (e.g. tear down all of `hml`'s `workload` to save cost) without dragging networking along — instead of an all-or-nothing `destroy`.
- **No secrets in the repository.** The code/config/secret split keeps `tfvars` committable and pushes every sensitive value to `TF_VAR_*` in CI.

The cost of these gains is in the trade-off table above — chiefly the ordering that becomes an operational contract and the outputs that become a public API. At this scale, the trade pays off.

---

> **Part 1:** keyless auth, plan-on-PR, gated apply, confirmed destroy → [Shipping Serverless Infrastructure on GCP with Terraform]([Part 1 link]).

---

*Part 2 of 2. Built with Terraform, Cloud Run, and GitHub Actions on Google Cloud.*
