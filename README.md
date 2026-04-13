# GCP Serverless Platform — Terraform

Production-grade serverless infrastructure on Google Cloud Platform. Two-tier web application (frontend + backend API + managed PostgreSQL) provisioned with Terraform, using Cloud Run v2 with Direct VPC Egress, path-based Global Load Balancing, and Cloud Armor WAF.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system diagram and component reference.

---

## Prerequisites

| Tool | Minimum Version | Notes |
|---|---|---|
| Terraform | >= 1.5.0 | `terraform -version` |
| gcloud CLI | any recent | `gcloud version` |
| Google Terraform provider | >= 5.0.0 | declared in `version.tf` |

**Authentication:**
```bash
gcloud auth application-default login
gcloud config set project <project-id>
```

---

## Project Structure

```
.
├── main.tf                     # Root orchestration — wires foundation → workload
├── variables.tf                # Root input variables
├── version.tf                  # Backend (GCS) and provider version constraints
├── terraform.tfvars            # Local variable values (not committed)
│
├── foundation/                 # Layer 1: Core networking
│   ├── main.tf                 # VPC, subnets, PSA, firewall
│   ├── state_bucket.tf         # Documents state bucket (not managed by Terraform)
│   ├── variables.tf
│   ├── outputs.tf
│   └── version.tf
│
├── workload/                   # Layer 2: Compute, data, and application resources
│   ├── main.tf                 # Cloud Run, LB, SQL, secrets, IAM, monitoring
│   ├── variables.tf
│   ├── outputs.tf
│   └── version.tf
│
└── modules/
    ├── foundation/
    │   ├── vpc/                # VPC, subnets, PSA range + peering, flow logs
    │   └── cloud_firewall/     # Firewall rules
    └── workload/
        ├── cloud_run_service/  # Cloud Run v2 service + Direct VPC Egress
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

The infrastructure is split into two Terraform root modules with a hard dependency contract:

```
root main.tf
├── module "foundation"   →   VPC, subnets, PSA, firewall
└── module "workload"     →   everything application-specific
                              (depends_on: foundation)
```

**Foundation** owns the network. It must exist before any workload resource is created, and must outlive all workload resources during teardown. Nothing application-specific lives here.

**Workload** owns compute and data. It consumes VPC outputs from foundation (`vpc_network_id`, `private_subnet_id`) as inputs. It cannot be created before foundation and is destroyed before foundation.

This split encodes the dependency contract in the module graph — Terraform enforces creation and destruction ordering automatically.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Compute | Cloud Run v2 (not GKE) | No cluster management, scale-to-zero, per-request billing |
| VPC connectivity | Direct VPC Egress (not VPC Connector) | Higher throughput, no connector bottleneck, private Cloud SQL access |
| LB routing | Path-based at LB layer (`/api/*` → backend, `/*` → frontend) | Cloud Armor covers both services; frontend not in API request path |
| Database access | PSA private IP (not Cloud SQL Auth Proxy) | Lower latency, no sidecar, network-level enforcement |
| Secret injection | Secret Manager env var refs | Secrets never in plaintext; versioned and auditable |
| State backend | GCS remote state | Shared state; versioning enabled |
| Ingress default | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Secure by default; public access must be explicitly opted into |

---

## Usage

### First-Time Setup

The Terraform state bucket must exist before `terraform init`. It is intentionally **not** managed by Terraform — if it were, `terraform destroy` would delete the bucket while the state lock is still held.

Create the bucket once:
```bash
gcloud storage buckets create gs://<project-id>-terraform-state \
  --location=US-CENTRAL1 \
  --uniform-bucket-level-access \
  --project=<project-id>

gcloud storage buckets update gs://<project-id>-terraform-state --versioning
```

Then initialize and apply:
```bash
terraform init
terraform apply
```

**Required variables** (`terraform.tfvars`):
```hcl
project_id     = "<your-gcp-project-id>"
db_password    = "<postgresql-password>"
api_secret_key = "<api-secret>"
```

Optional:
```hcl
name        = "app"          # resource name prefix, default: "app"
region      = "us-central1"  # default: "us-central1"
domain_name = "example.com"  # enables HTTPS + managed SSL cert
```

### Destroy

> **Important:** Destroying this infrastructure is a two-phase operation. Cloud Run v2 with Direct VPC Egress causes GCP to hold internal IP reservations on the subnet for **up to 120 minutes** after service deletion. A single `terraform destroy` will fail trying to delete the subnet while those IPs are still held.

**Phase 1 — destroy all workload resources:**
```bash
terraform destroy -target=module.workload -auto-approve
```

**Wait** — GCP must release the Direct VPC Egress IP reservations from the subnet. This typically takes 15–30 minutes but can take up to 120 minutes.

**Phase 2 — destroy the foundation (network):**
```bash
terraform destroy -auto-approve
```

Phase 2 will also run `time_sleep` timers (150s for VPC Egress, 600s for PSA lock release) before deleting the subnet and VPC. Total expected duration for both phases: **20–30 minutes** (plus any wait between phases).

The state bucket is preserved after destroy. Delete it manually when no longer needed:
```bash
gcloud storage rm -r gs://<project-id>-terraform-state
```

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

### Subnet deletion fails: `subnetwork is already being used by serverless-ipv4-*`

```
Error: The subnetwork resource '...app-vpc-private' is already being used by
'...addresses/serverless-ipv4-1234567890'
```

**Cause:** Cloud Run v2 with Direct VPC Egress causes GCP to create internal IP reservations on the subnet. GCP holds these reservations for up to 120 minutes after the Cloud Run service is deleted — this is a GCP-internal behavior with no public API to force-release them.

**Resolution:** Wait, then retry:
```bash
# Wait until this returns empty
gcloud compute addresses list \
  --project=<project-id> \
  --regions=us-central1 \
  --filter="name~serverless-ipv4"

# Then delete the remaining resources
gcloud compute networks subnets delete app-vpc-private \
  --region=us-central1 --project=<project-id> --quiet

gcloud services vpc-peerings delete \
  --network=app-vpc --project=<project-id> --quiet

gcloud compute addresses delete app-vpc-psa-range \
  --global --project=<project-id> --quiet

gcloud compute networks delete app-vpc \
  --project=<project-id> --quiet
```

After manual cleanup, remove the stale entries from Terraform state:
```bash
terraform state rm module.foundation.module.vpc.google_compute_subnetwork.private
terraform state rm module.foundation.module.vpc.google_compute_network.this
# etc. for remaining foundation resources
```

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
