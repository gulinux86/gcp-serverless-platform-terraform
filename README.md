# GCP Serverless Platform — Terraform

Production-grade serverless infrastructure on Google Cloud Platform. Two-tier web application (frontend + backend API + managed PostgreSQL) provisioned with Terraform, using Cloud Run v2 with a Serverless VPC Access Connector, path-based Global Load Balancing, and Cloud Armor WAF. Two independent Terraform layers, per-environment state (`hml`/`prod`), and a full GitHub Actions delivery pipeline with keyless (WIF) auth.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system diagram and component reference.

---

## Prerequisites

| Tool | Minimum Version | Notes |
|---|---|---|
| Terraform | >= 1.7.0 | `terraform -version` (module tests use `mock_provider`) |
| gcloud CLI | any recent | `gcloud version` |
| Google Terraform provider | >= 5.0.0 | declared in each layer's `version.tf` |

**Authentication:**
```bash
gcloud auth application-default login
gcloud config set project <project-id>
```

---

## Project Structure

```
.
├── .github/workflows/          # CI/CD: test, security-scan, plan, deploy, destroy
│
├── bootstrap/                  # One-time: Workload Identity Federation + deployer SA
│   ├── main.tf                 # WIF pool/provider, deployer SA, IAM (per env)
│   └── environments/{hml,prod}/terraform.tfvars
│
├── foundation/                 # Layer 1 (independent root): core networking
│   ├── main.tf                 # VPC, subnets, VPC Connector, PSA, firewall
│   ├── provider.tf             # google provider (per layer)
│   ├── state_bucket.tf         # Documents state bucket (not managed by Terraform)
│   ├── version.tf              # Partial GCS backend + provider constraints
│   ├── variables.tf · outputs.tf
│   └── environments/{hml,prod}/{backend.hcl,terraform.tfvars}
│
├── workload/                   # Layer 2 (independent root): compute, data, app
│   ├── main.tf                 # Cloud Run, LB, SQL, secrets, IAM, monitoring
│   ├── remote_state.tf         # Reads foundation's remote state
│   ├── provider.tf · version.tf · variables.tf · outputs.tf
│   └── environments/{hml,prod}/{backend.hcl,terraform.tfvars}
│
├── docs/STATE_MIGRATION.md     # Single-root → two-layer migration runbook
│
└── modules/
    ├── foundation/
    │   ├── vpc/                # VPC, subnets, VPC Connector, PSA range + peering, flow logs
    │   └── cloud_firewall/     # Firewall rules
    └── workload/
        ├── cloud_run_service/  # Cloud Run v2 service + VPC Connector egress
        ├── cloud_sql/          # PostgreSQL private instance
        ├── cloud_storage/      # GCS bucket
        ├── https_load_balancer/# Global LB + path routing + Cloud Armor attachment
        ├── cloud_armor/        # WAF security policy
        ├── iam_service_account/# Service account + role bindings
        ├── artifact_registry/  # Docker image repository
        ├── secret_manager/     # Secret + rotation config
        ├── secret_rotation/    # Pub/Sub + Cloud Run Job rotation handler
        └── pubsub/             # Pub/Sub topic primitive
```

---

## Architecture

### Two-Layer Design

The infrastructure is split into two **independent Terraform root modules** — there is no root orchestrator. The dependency contract is enforced by remote state + the CI pipelines, not by a parent module:

```
foundation/  ── apply ──▶  GCS state (gs://<bucket>/<env>/foundation/)
                                 │
workload/    ── reads ───────────┘   data.terraform_remote_state.foundation
             ── apply ──▶  GCS state (gs://<bucket>/<env>/workload/)
```

**Foundation** owns the network (VPC, subnets, VPC Access Connector, PSA, firewall). It must be applied before workload and destroyed after it.

**Workload** owns compute and data. It reads foundation's outputs (`vpc_network_id`, `vpc_connector_id`, `psa_connection_id`) from remote state via `workload/remote_state.tf` — so it cannot plan until foundation is applied. The `terraform-deploy`/`terraform-destroy` pipelines enforce the apply/destroy ordering; `terraform-plan` skips the workload plan with a clear message when foundation has no outputs yet.

Each layer is applied per environment by selecting a backend config:
`terraform -chdir=<layer> init -backend-config=environments/<env>/backend.hcl`.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Compute | Cloud Run v2 (not GKE) | No cluster management, scale-to-zero, per-request billing |
| VPC connectivity | Serverless VPC Access Connector (not Direct VPC Egress) | No stranded subnet IP reservations on destroy — removes the IP-release cooldowns |
| LB routing | Path-based at LB layer (`/api/*` → backend, `/*` → frontend) | Cloud Armor covers both services; frontend not in API request path |
| Database access | PSA private IP (not Cloud SQL Auth Proxy) | Lower latency, no sidecar, network-level enforcement |
| Secret injection | Secret Manager env var refs | Secrets never in plaintext; versioned and auditable |
| Layering | Two independent roots + per-env state | Smaller blast radius; `workload` reads `foundation` via remote state |
| CI/CD auth | Workload Identity Federation (keyless) | No long-lived SA keys in GitHub (see `bootstrap/`) |
| Ingress default | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Secure by default; public access must be explicitly opted into |

---

## Usage

### First-Time Setup

**1. State bucket** (must exist before `init`; intentionally **not** managed by Terraform, so `destroy` never deletes it while the lock is held):
```bash
gcloud storage buckets create gs://<project-id>-terraform-state \
  --location=US-CENTRAL1 --uniform-bucket-level-access --project=<project-id>
gcloud storage buckets update gs://<project-id>-terraform-state --versioning
```
Set this bucket name in each layer's `environments/<env>/backend.hcl` (and in the workload tfvars `state_bucket`).

**2. Bootstrap keyless CI auth** (once per environment, with owner credentials):
```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply -var-file=environments/hml/terraform.tfvars
# Copy the two outputs into GitHub secrets: HML_WIF_PROVIDER, HML_DEPLOYER_SA
```
Also set `HML_DB_PASSWORD` / `HML_API_SECRET_KEY` (and the `PROD_*` equivalents) as GitHub secrets, and add a required reviewer to the `prod` GitHub Environment. See [bootstrap/](bootstrap/).

**3. Fill the per-env tfvars** — replace the `REPLACE-WITH-*` placeholders in `foundation/environments/<env>/terraform.tfvars` and `workload/environments/<env>/terraform.tfvars`. Sensitive values (`db_password`, `api_secret_key`) are **never** committed — they come from `TF_VAR_*` env vars / GitHub secrets.

**4. Deploy.** Normally via the `terraform-deploy` workflow (pick `environment` + `layer`). Locally, foundation first:
```bash
ENV=hml
terraform -chdir=foundation init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=foundation apply -var-file=environments/$ENV/terraform.tfvars

export TF_VAR_db_password=... TF_VAR_api_secret_key=...
terraform -chdir=workload init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=workload apply -var-file=environments/$ENV/terraform.tfvars
```

### Destroy

Switching to the VPC Access Connector removed the old multi-phase IP-release wait. Destroy is now a normal per-layer teardown in reverse order (**workload before foundation**), which the `terraform-destroy` workflow handles when you pick `layer: both`. Locally:
```bash
ENV=hml
terraform -chdir=workload destroy -var-file=environments/$ENV/terraform.tfvars
terraform -chdir=foundation destroy -var-file=environments/$ENV/terraform.tfvars
```
The foundation destroy still waits ~10 min on the PSA lock buffer (`decommissioning_buffer`) before removing the peering and VPC. The state bucket is preserved; delete it manually when no longer needed.

See [docs/STATE_MIGRATION.md](docs/STATE_MIGRATION.md) if migrating from the old single-root layout.

---

## CI/CD

Five GitHub Actions workflows in `.github/workflows/` (one per pipeline):

| Workflow | Trigger | What it does |
|---|---|---|
| `terraform-test` | PR | Module unit tests (`mock_provider`, no creds) |
| `security-scan` | PR | Trivy IaC scan, fails on HIGH/CRITICAL, uploads SARIF |
| `terraform-plan` | PR + dispatch | Plan per layer (env inferred from base branch), posted as a PR comment; skips workload when foundation isn't applied |
| `terraform-deploy` | manual dispatch | Gated by tests + Trivy; applies a saved plan; pick `environment` + `layer [foundation\|workload\|both]` |
| `terraform-destroy` | manual dispatch | Typed confirmation; reverse-order teardown |

All cloud-touching workflows authenticate via **Workload Identity Federation** (no static keys). `prod` runs pause for approval via the `prod` GitHub Environment.

---

## Security Model

Defense in depth — six layers:

**1. Cloud Armor WAF**
Applied to both the frontend and API backend services on the Global Load Balancer. Rules: OWASP Top 10 managed rules (SQLi, XSS), rate limiting (100 req/min per IP → 429), and ML-based Adaptive Protection.

**2. Load Balancer Ingress Restriction**
Both Cloud Run services are configured with `ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`. Direct `*.run.app` requests are rejected with HTTP 403. All traffic must pass through the LB and Cloud Armor.

**3. Path-Based Routing (no frontend proxy)**
`/api` and `/api/*` routes are handled by the LB URL map directly to the backend Cloud Run service. The frontend never proxies API requests — all traffic paths are covered by Cloud Armor at the LB.

**4. Database Isolation**
Cloud SQL has no public IP. It is reachable only via Private Service Access (PSA) peering from within the VPC. The backend service account has `roles/cloudsql.client` only — not admin.

**5. Secret Management**
Secrets (`app-api-key`, `db-password`) are stored in Secret Manager and injected as environment variable references at Cloud Run runtime. Plaintext values never appear in Terraform state or container config. Automatic 30-day rotation via Pub/Sub + Cloud Run Job. Service accounts have `roles/secretmanager.secretAccessor` scoped per-secret (not project-wide).

**6. Audit Logging**
All `cloudaudit.googleapis.com` logs are exported to a GCS bucket with a 365-day retention lifecycle rule. The audit log bucket has `force_destroy = false` to preserve logs even if the infrastructure is destroyed.

### IAM — Principle of Least Privilege

| Service Account | Role | Scope |
|---|---|---|
| `backend-sa` | `roles/cloudsql.client` | Project |
| `backend-sa` | `roles/storage.objectViewer` | Project |
| `backend-sa` | `roles/secretmanager.secretAccessor` | `app-api-key` secret only |
| `backend-sa` | `roles/secretmanager.secretAccessor` | `db-password` secret only |
| `frontend-sa` | `roles/storage.objectViewer` | Project |
| `rotation-invoker` | `roles/run.invoker` | Secret rotation Cloud Run Job only |

---

## Troubleshooting

### Workload plan fails: foundation outputs not found

**Cause:** The `workload` layer reads `foundation`'s remote state. If foundation
hasn't been applied for that environment (or was destroyed), there are no outputs
to read.

**Resolution:** Apply `foundation` for the environment first (`terraform-deploy`
→ `layer: foundation`), then re-run. The `terraform-plan` workflow already detects
this and skips the workload plan with an explanatory message instead of erroring.

> **Note:** The previous "subnetwork is already being used by `serverless-ipv4-*`"
> failure no longer occurs. It was caused by Direct VPC Egress holding IP
> reservations in the subnet; the Serverless VPC Access Connector (its own `/28`,
> managed resource) removed that class of teardown failure.

---

### State lock error: `Error acquiring the state lock`

```
Error: Error acquiring the state lock
Lock Info:
  ID: 1234567890
  Operation: OperationTypeApply
```

**Cause:** A previous Terraform operation was interrupted without releasing the lock, or two concurrent operations were attempted.

**Resolution:** Verify no Terraform process is actively running, then force-unlock:
```bash
terraform force-unlock -force <lock-id>
```

Replace `<lock-id>` with the ID shown in the error message.
