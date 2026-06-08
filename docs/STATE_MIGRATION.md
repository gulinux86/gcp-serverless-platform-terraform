# State Migration — single root → two independent layers

This project moved from a **single root module** (one `main.tf` orchestrating
`foundation` and `workload` as submodules, state prefix `root`) to **two
independent root layers**, each with its own per-environment state:

```
OLD (one state)                 NEW (four states, env-prefixed)
gs://<bucket>/root/             gs://<bucket>/hml/foundation/
                                gs://<bucket>/hml/workload/
                                gs://<bucket>/prod/foundation/
                                gs://<bucket>/prod/workload/
```

On top of the restructure, the resource graph itself changed:

- **VPC Access Connector added** (`module.vpc.google_vpc_access_connector.this`) —
  not present in the old state.
- **IP-release guards removed** — `time_sleep.wait_for_ip_release`,
  `time_sleep.vpc_egress_release_guard`, and `terraform_data.serverless_signal`
  no longer exist.
- **Addresses reshaped** — old `module.foundation.module.vpc.*` becomes
  `module.vpc.*` in the foundation state; old `module.workload.module.backend.*`
  becomes `module.backend.*` in the workload state.

Because the graph changed this much, **a clean re-apply is the recommended path.**
State surgery is possible but brittle (see the appendix) and not worth it for a
greenfield/portfolio environment.

---

## Recommended: clean re-apply (per environment)

> Prerequisite: the bootstrap WIF + deployer SA exist (see `bootstrap/`) OR you
> run these locally with your own credentials. The state bucket must already
> exist and is never managed by Terraform.

### 1. Tear down the OLD stack (if it was ever applied)

If you have a live `root` state, destroy it using the pre-migration code from git
history (the commit before this change), so the old graph (with its guards) tears
down in its own ordering:

```bash
git stash || true
git checkout <pre-migration-commit> -- .
terraform init   # old root backend (prefix "root")
terraform destroy -var-file=<your old tfvars>
git checkout HEAD -- .   # back to the new code
```

If nothing was ever applied (fresh project), skip this step.

### 2. Apply the NEW layers, foundation first

```bash
ENV=hml   # then repeat with ENV=prod

# foundation
terraform -chdir=foundation init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=foundation apply -var-file=environments/$ENV/terraform.tfvars

# workload (reads foundation's remote state — must come after)
export TF_VAR_db_password=...      # never commit these
export TF_VAR_api_secret_key=...
terraform -chdir=workload init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=workload apply -var-file=environments/$ENV/terraform.tfvars
```

In CI this is exactly `terraform-deploy` with `layer: both`.

### 3. Verify

```bash
terraform -chdir=workload plan -var-file=environments/$ENV/terraform.tfvars
# expect: No changes. (workload resolved foundation outputs with no drift)
```

---

## Appendix: in-place state surgery (advanced, optional)

Only if you must preserve live resources you cannot recreate. Outline:

```bash
# 1. Pull the old combined state
terraform init   # old root
terraform state pull > root.tfstate

# 2. Move foundation-side resources into a new foundation state, stripping the
#    module.foundation. prefix (repeat per resource / use `terraform state mv`
#    with -state / -state-out against working copies).
#    e.g. module.foundation.module.vpc.google_compute_network.this
#         -> module.vpc.google_compute_network.this

# 3. Same for workload: module.workload.module.backend.* -> module.backend.*

# 4. `terraform state rm` the removed guards:
#    module.workload.time_sleep.vpc_egress_release_guard
#    module.foundation.module.vpc.terraform_data.serverless_signal[0]
#    module.workload.module.backend.time_sleep.wait_for_ip_release
#    module.workload.module.frontend.time_sleep.wait_for_ip_release

# 5. Push each split state to its env-prefixed backend, then run `plan`.
#    The VPC Access Connector will show as a CREATE (it is genuinely new).
```

This is error-prone (address rewriting, the connector create, PSA/peering
ordering). Prefer the clean re-apply unless you have irreplaceable state.
