---
title: "Testing Terraform Modules Without Touching the Cloud"
subtitle: "mock_provider, command = plan, and encoding security invariants as code — a fast, credential-free gate that runs on every PR."
tags: [Terraform, GCP, Testing, InfrastructureAsCode, DevOps]
---

# Testing Terraform Modules Without Touching the Cloud

> **Companion piece** to the delivery-pipeline series: [Shipping Serverless Infrastructure on GCP with Terraform]([Part 1 link]) and [Terraform State Topology]([Part 2 link]). This one goes one layer deeper — the module tests that gate every PR before any plan or apply runs.

Terraform fails quietly. A broken conditional (`count`/`for_each` with a ternary) produces no error — it produces *zero resources*, and infrastructure disappears from the plan without a warning. A misconfigured Cloud SQL instance doesn't error either — it provisions a less secure instance with a public IP. Code review catches a static resource in seconds; it does not catch a dynamic block that silently renders empty.

This is what `terraform test` guards against. This platform ships **8 test files, ~45 scenarios across 7 modules**, all running in seconds, on every PR, with no GCP credentials and no cloud cost. Here is how, and what they actually assert.

---

## The technique: `mock_provider` + `command = plan`

Every test file opens the same way:

```hcl
mock_provider "google" {}

variables {
  name  = "test-service"
  image = "gcr.io/test-project/app:latest"
}

run "scale_to_zero_by_default" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0
    error_message = "Default min_instance_count must be 0 (scale to zero). Warm instances have a per-second cost — the caller must explicitly opt in to min=1."
  }
}
```

Two choices define the whole approach:

- **`mock_provider "google" {}`** — the provider is mocked, so the test never authenticates and never calls the GCP API. The provider binary is downloaded by `init` but never invoked.
- **`command = plan`** — assertions run against the *planned* values, not applied infrastructure. Nothing is created, nothing is destroyed.

The payoff: **zero cost, runs in seconds, no credentials.** The cost: these tests validate *structure and logic*, not real cloud behavior. They will never catch a quota error, an IAM gap, or a rejected rule expression that GCP evaluates server-side. They are a fast first gate, not a substitute for a real plan against a real project.

---

## What the tests assert

The ~45 scenarios fall into five categories. Each targets a specific failure mode Terraform won't surface on its own.

### 1. Security invariants as non-negotiable

The most valuable tests treat a security default as an invariant, not a configuration option — a regression guard against a future change that quietly relaxes it.

```hcl
# cloud_sql/private_access.tftest.hcl
run "database_never_has_public_ip" {
  command = plan
  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Cloud SQL must NEVER have a public IPv4 address ... A public IP exposes the instance regardless of authorized_networks settings."
  }
}
```

Same pattern across modules:

- **Cloud Run** — default ingress is `INGRESS_TRAFFIC_INTERNAL_ONLY`, never `INGRESS_TRAFFIC_ALL`; a service is only reachable from the internet when `make_public = true`, and even then the binding is exactly `roles/run.invoker` to `allUsers`, nothing broader.
- **IAM service accounts** — no service-account *key* is created by default (long-lived credentials that bypass IAM Conditions); no project-level roles by default. Least privilege is an opt-in, not an opt-out.
- **Cloud Armor** — at least two `deny(403)` rules (XSS at priority 1000, SQLi at 1001) must always exist; Layer-7 DDoS adaptive protection cannot be turned off.

The point: "least privilege" written only in documentation is meaningless if the module *defaults* can silently grant more. The test makes the default executable.

### 2. Conditional resources — the silent empty plan

Conditional blocks are the most common source of silent regressions. These tests assert the resource count in both states — present *and* absent:

```hcl
# cloud_run_service/conditional_resources.tftest.hcl
run "no_vpc_access_without_connector" {
  command = plan
  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].vpc_access) == 0
    error_message = "No vpc_access block must be rendered when vpc_connector_id is null — an empty connector reference is invalid at apply time."
  }
}
```

The companion test sets `vpc_connector_id` and asserts the block *is* rendered with `egress = "ALL_TRAFFIC"`. Testing both sides is the whole value: a refactor that breaks the conditional yields zero resources and zero errors — infrastructure vanishes silently otherwise.

### 3. Variable validation via `expect_failures`

Tests also prove that `validation` blocks actually reject bad input — at plan time, not apply time:

```hcl
# cloud_run_service/ingress_security.tftest.hcl
run "validation_rejects_invalid_ingress_value" {
  command = plan
  variables { ingress = "DIRECT_INTERNET_EXPOSURE" }
  expect_failures = [var.ingress]
}
```

Without this, someone could delete the `validation` block and the module would accept any string — GCP would reject it at apply time (slow, mid-deploy) instead of at plan time (fast, pre-merge).

### 4. The multi-mode matrix

The `https_load_balancer` module has four operating modes driven by two optional variables (`domain`, `api_cloud_run_service_name`). Each combination creates a different resource set, and a broken mode is invisible in code review — a missing HTTPS resource produces no error, just a silent HTTP-only LB. So all four modes are tested explicitly: HTTP-only, TLS-with-domain, API path-routing, and full production (TLS + path routing). The tests also assert mutual exclusion — the simple `url_map.this` must *not* exist when the path-based `url_map.with_api` is active, or the two would conflict.

### 5. Convention and contract

A thin layer of tests pins naming patterns (`<name>-policy`) and rule priorities, because Cloud Armor rule ordering is significant — changing a priority can cause rule shadowing.

---

## The CI gate

The tests run as their own workflow, `terraform-test.yml`, on every PR that touches `modules/**`:

```yaml
permissions:
  contents: read            # read-only — no GCP credentials, no state writes

strategy:
  fail-fast: false          # run all modules even if one fails — full picture
  matrix:
    module: [ modules/foundation/vpc, modules/foundation/cloud_firewall, ... ]

steps:
  - uses: hashicorp/setup-terraform@... 
    with: { terraform_version: "~> 1.9" }   # mock_provider needs >= 1.7
  - run: terraform init -backend=false       # modules have no backend
  - run: terraform test
```

Three decisions worth calling out:

- **Matrix with `fail-fast: false`.** Each module is its own job, and one failure does not cancel the others — a broken PR shows the *complete* picture of what regressed, not just the first failure.
- **Read-only permissions, no credentials.** `permissions: contents: read`, `init -backend=false`. The job structurally *cannot* touch cloud state — the mocked provider is never called.
- **Version pinning is load-bearing.** `mock_provider` requires Terraform ≥ 1.7, so the test workflow pins `~> 1.9`. The plan/deploy pipelines stay on `~> 1.5` because they target root modules with real backends. The two version lines are intentional, not drift.

This is the first of two gates before any apply (the second is the Trivy security scan). A failure here blocks the merge — the test gate fails closed.

---

## Trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| `mock_provider` + `command = plan` | Zero cost, seconds, no credentials | Validates structure/logic only — never real cloud behavior (quotas, IAM, server-side validation) |
| Security defaults as invariants | A relaxed default fails the build, not production | Tightly coupled to resource attribute paths; provider schema changes can break assertions |
| Testing both sides of every conditional | Catches the silent empty plan | More scenarios to write and maintain |
| `expect_failures` on validation blocks | Moves bad-input rejection from apply-time to plan-time | Only as good as the validation rules it guards |
| Per-module matrix in CI | Full regression picture; isolated failures | More jobs; minor CI minutes overhead |
| Terraform ≥ 1.9 for tests, ~1.5 for roots | Each context runs its right version | Two version lines to keep straight; "works on my machine" if local Terraform drifts from CI |

---

## Takeaways

- **Terraform's dangerous failures are silent.** A broken conditional or a relaxed security default produces no error — just wrong infrastructure. Tests are the only thing that turns that into a red build.
- **`mock_provider` + `command = plan` is the fast gate.** Seconds, no credentials, no cost. It catches refactor regressions, not cloud-side errors — pair it with a real plan, don't replace one with the other.
- **Encode security defaults as invariants.** A default that's only documented can be silently relaxed; a default with a test cannot.
- **Test both sides of every conditional.** Asserting the resource is absent is as important as asserting it's present.
- **Pin the test runner's Terraform version.** `terraform test` semantics shift between minor releases; align local and CI or "works on my machine" becomes a real failure mode.

The tests don't prove the infrastructure works in production — a real plan does that. They prove the *module logic* and the *security posture* survive every refactor, before the change ever reaches a cloud credential.

---

*Companion to the GCP serverless platform series. Built with Terraform, Cloud Run, and GitHub Actions on Google Cloud.*
