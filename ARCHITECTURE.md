# Architecture

This document outlines a serverless-first GCP architecture for a two-tier web application, featuring a strictly isolated environment provisioned entirely through modular Terraform.

---

## Full Architecture Diagram

```
                          ┌─────────────────────────────────────────────────────┐
                          │                  Public Internet                    │
                          └─────────────────────┬───────────────────────────────┘
                                                │
                                    ┌───────────▼───────────┐
                                    │   Global Anycast IP    │
                                    │   (34.8.68.173)        │
                                    └───────────┬────────────┘
                                                │
                              ┌─────────────────▼──────────────────┐
                              │      Cloud Armor WAF               │
                              │  OWASP Top 10 · Rate Limit · DDoS  │
                              └─────────────────┬──────────────────┘
                                                │
                              ┌─────────────────▼──────────────────┐
                              │   Global HTTPS Load Balancer        │
                              │   (EXTERNAL_MANAGED)                │
                              │                                     │
                              │   URL Map (path-based routing):     │
                              │   /api   /api/* ──▶ API backend     │
                              │   *      (default) ──▶ Frontend     │
                              └──────────┬──────────────┬───────────┘
                                         │              │
                   ┌─────────────────────▼─┐       ┌───▼──────────────────────┐
                   │   Cloud Run (frontend) │       │   Cloud Run (backend)    │
                   │   ingress: LB only     │       │   ingress: LB only       │
                   │   SA: frontend-sa      │       │   SA: backend-sa         │
                   │   Direct VPC Egress    │       │   Direct VPC Egress      │
                   │   GCS FUSE mount       │       │   Secret Manager refs    │
                   └───────────────────────┘       └────────────┬─────────────┘
                                                                │
                                          ┌─────────────────────▼──────────────────┐
                                          │              VPC Network                │
                                          │            (app-vpc)                    │
                                          │                                         │
                                          │  ┌─────────────────────────────────┐   │
                                          │  │  Private Subnet (app-vpc-private)│   │
                                          │  │  10.0.2.0/24                    │   │
                                          │  │  Cloud Run network interfaces   │   │
                                          │  └────────────────┬────────────────┘   │
                                          │                   │ PSA peering         │
                                          │  ┌────────────────▼────────────────┐   │
                                          │  │   Cloud SQL (PostgreSQL 15)     │   │
                                          │  │   Private IP only · REGIONAL    │   │
                                          │  │   (app-db · db-f1-micro)        │   │
                                          │  └─────────────────────────────────┘   │
                                          └──────────────────────────────────────┘
                                                         │
                              ┌──────────────────────────▼───────────────────────┐
                              │              Supporting Services                  │
                              │                                                   │
                              │  Cloud Storage  ──  GCS FUSE mount in Cloud Run  │
                              │  Artifact Registry  ──  Docker image storage      │
                              │  Secret Manager  ──  app-api-key, db-password    │
                              │  Pub/Sub  ──  secret rotation trigger topic       │
                              │  Cloud Run Job  ──  secret rotation handler       │
                              │  Cloud Monitoring  ──  error rate + latency alerts│
                              │  Cloud Logging  ──  audit log sink → GCS bucket  │
                              └───────────────────────────────────────────────────┘
```

---

## Infrastructure Layers

The project uses a **strictly isolated two-layer architecture**. Each layer is an **independent Terraform root module with its own per-environment state** — there is no root orchestrator. The `workload` layer consumes the `foundation` layer's outputs by reading its **remote state**, which makes "foundation before workload" a hard dependency enforced by the CI pipelines.

```
foundation/   (root)  ── apply ──▶  GCS state  gs://<bucket>/<env>/foundation/
                                          │
workload/     (root)  ── reads ──────────┘  (data.terraform_remote_state.foundation)
                      ── apply ──▶  GCS state  gs://<bucket>/<env>/workload/
```

State is separated per environment (`hml`, `prod`) and per layer via env-prefixed
backend paths selected at init: `init -backend-config=environments/<env>/backend.hcl`.
See [STATE_MIGRATION.md](docs/STATE_MIGRATION.md) for the layout and migration notes.

### Layer 1 — Foundation (Core Networking)

**Location:** `foundation/`

Owns the base networking environment. Nothing application-specific lives here. The foundation must exist before any workload resource can be created, and must outlive all workload resources during teardown.

| Resource | Module | Purpose |
|----------|--------|---------|
| VPC Network | `modules/foundation/vpc` | Custom VPC, no auto-subnets |
| Private Subnet | `modules/foundation/vpc` | `10.0.2.0/24` — application subnet |
| Secondary Subnet | `modules/foundation/vpc` | `10.0.3.0/24` — reserved for future use |
| Cloud Run egress path | `modules/foundation/vpc` | The private subnet doubles as the Direct VPC Egress attachment point for Cloud Run (see §Cloud Run egress) |
| PSA IP Range | `modules/foundation/vpc` | `/16` — Cloud SQL private connectivity |
| Service Networking Connection | `modules/foundation/vpc` | Peering for managed services (Cloud SQL) |
| Firewall Rules | `modules/foundation/cloud_firewall` | Allow ports 443 + 8080 from RFC-1918 |
| VPC Flow Logs | `modules/foundation/vpc` | Full metadata logging on private subnet |
| Terraform State Bucket | `foundation/state_bucket.tf` | GCS bucket for remote state |

### Layer 2 — Workload (Compute & Data)

**Location:** `workload/`

Owns everything application-specific. Reads the foundation layer's remote state for networking outputs (`vpc_network_id`, `private_subnet_id`, `psa_connection_id`) — see `workload/remote_state.tf`.

| Resource Group | Modules Used | Purpose |
|----------------|-------------|---------|
| IAM | `workload/iam_service_account` | `backend-sa`, `frontend-sa` — PoLP identities |
| Artifact Registry | `workload/artifact_registry` | Docker image store for Cloud Run |
| Cloud Run (frontend) | `workload/cloud_run_service` | Frontend app, LB ingress only |
| Cloud Run (backend) | `workload/cloud_run_service` | Backend API, LB ingress only, GCS FUSE mount |
| Cloud SQL | `workload/cloud_sql` | PostgreSQL 15, private IP via PSA, no public IP |
| Cloud Storage | `workload/cloud_storage` | App file storage, FUSE-mounted in backend |
| Secret Manager | `workload/secret_manager` | `app-api-key`, `db-password` with 30-day rotation |
| Secret Rotation | `workload/secret_rotation` | Pub/Sub topic + Cloud Run Job for automated rotation |
| Cloud Armor | `workload/cloud_armor` | WAF security policy (OWASP + rate limit + Adaptive Protection) |
| HTTPS Load Balancer | `workload/https_load_balancer` | Global LB, path routing, Cloud Armor attachment |
| Monitoring | inline in `workload/main.tf` | Alert policies: frontend error rate, latency, SQL disk |
| Audit Logging | inline in `workload/main.tf` | Project audit log sink → GCS bucket (365-day retention) |

---

## Request Flow

```
Client
  │
  │  HTTP :80
  ├──────────────────▶  HTTP Forwarding Rule
  │                          │
  │                    (no domain: routes directly)
  │                    (domain set: 301 → HTTPS)
  │
  │  HTTPS :443 (when domain configured)
  └──────────────────▶  HTTPS Forwarding Rule
                              │
                        Cloud Armor WAF
                              │
                         HTTPS Proxy
                              │
                          URL Map
                         /       \
               /api, /api/*       * (default)
                    │                  │
           API Backend NEG       Frontend NEG
                    │                  │
          Cloud Run (backend)  Cloud Run (frontend)
                    │
              (private network)
                    │
               Cloud SQL
```

---

## Security Model

### Defense in Depth

```
Layer 1: Cloud Armor WAF
  - OWASP Top 10 managed rules (SQLi, XSS, etc.)
  - Rate limiting: 100 req/min per IP → 429
  - Adaptive Protection: ML-based DDoS detection
  - Applied to BOTH frontend and backend LB backend services

Layer 2: Load Balancer Ingress Restriction
  - Both Cloud Run services: ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER
  - Direct *.run.app access rejected (HTTP 403)
  - All traffic must pass through LB → Cloud Armor

Layer 3: Service-to-Service (no longer needed)
  - Frontend no longer proxies to backend (LB handles routing)
  - frontend-sa IAM binding on backend removed

Layer 4: Database Isolation
  - Cloud SQL: no public IP
  - Reachable only via PSA peering from VPC
  - backend-sa has roles/cloudsql.client (read/write), not admin

Layer 5: Secret Management
  - Secrets stored in Secret Manager, never in env vars as plaintext
  - Secret env vars injected at runtime via Cloud Run secret references
  - backend-sa has secretAccessor only on its own secrets (PoLP)
  - Automatic 30-day rotation via Pub/Sub + Cloud Run Job

Layer 6: Audit Logging
  - All cloudaudit.googleapis.com logs exported to GCS
  - 365-day retention, force_destroy=false (preserved on terraform destroy)
```

### IAM Principle of Least Privilege

| Service Account | Roles | Scope |
|-----------------|-------|-------|
| `backend-sa` | `roles/cloudsql.client` | Project |
| `backend-sa` | `roles/storage.objectViewer` | Project |
| `backend-sa` | `roles/secretmanager.secretAccessor` | Per-secret (app-api-key, db-password) |
| `frontend-sa` | `roles/storage.objectViewer` | Project |
| `rotation-invoker` | `roles/run.invoker` | Secret rotation Cloud Run Job only |

---

## Cloud Run egress

Cloud Run reaches the VPC through **Direct VPC Egress**: each service attaches a
`network_interface` directly to the private subnet. There is no Serverless VPC
Access Connector in the path.

### Why not the connector

The connector was adopted, then abandoned after it could not be provisioned in
this project. Creation consistently failed after ~4–5 minutes with:

```
Error waiting for Creating Connector: Error code 13, message: An internal error
occurred: VPC Access connector failed to get healthy. Please check GCE quotas,
logs and org policies and recreate.
```

The message points at quotas, logs and org policies. All three were ruled out
with evidence:

| Suspect | Checked | Result |
|---|---|---|
| GCE quota | `CPUS 0/200`, `INSTANCES 0/24`, `IN_USE_ADDRESSES 0/8` | not the cause |
| Org policies | `requireShieldedVm` unenforced; `vmExternalIpAccess`, `trustedImageProjects` = ALLOW | not the cause |
| API / service agent | `vpcaccess.googleapis.com` enabled; agent holds `roles/vpcaccess.serviceAgent` | not the cause |
| Egress route | default `0.0.0.0/0` → internet gateway present | not the cause |

A second attempt addressed the two documented requirements the VPC did not yet
satisfy — an **explicit connector subnet with Private Google Access** (the
`ip_cidr_range` shortcut makes GCP provision a managed subnet where PGA cannot be
set) and **ingress on `tcp:667`** from Google's control-plane and health-check
ranges. It failed identically.

At that point the connector had cost two failed deploys and was providing no
capability that Direct VPC Egress does not. Direct VPC Egress is also Google's
current recommendation for new workloads, removes an idle cost of roughly
US$ 25–30/month per environment, and takes a managed component with its own
health lifecycle out of the critical path.

### What it costs

Direct VPC Egress holds a **per-instance IP reservation** in the private subnet,
and GCP releases those reservations asynchronously after the services are
deleted. Deleting the subnet before that cleanup finishes fails with
`resource in use`. Two cooldowns cover it:

| Guard | Where | Duration |
|---|---|---|
| `time_sleep.wait_for_ip_release` | `modules/workload/cloud_run_service` | 150s per service |
| `time_sleep.vpc_egress_release_guard` | `workload/main.tf` | 150s at layer level |

The layer-level guard fires regardless of per-service timer state, and the
destroy pipeline always tears down `workload` before `foundation`, so the
subnet is only deleted after both have elapsed.

### If the connector is revisited

A leftover connector is left in `ERROR` state and is **not** recorded in
Terraform state. Delete it before retrying, or the next apply fails with
`alreadyExists` instead of surfacing the real error:

```bash
gcloud compute networks vpc-access connectors delete <name> --region <region>
```

---

## Destroy Orchestration

Teardown has two independent hazards, each with its own guard.

1. **Layer order.** `workload` must be destroyed before `foundation` (the workload
   reads foundation's state and attaches to its subnet). The `terraform-destroy`
   pipeline enforces this (`layer: both` ⇒ `workload foundation`).
2. **Direct VPC Egress IP release.** GCP releases Cloud Run's per-instance subnet
   IP reservations asynchronously. Two 150s cooldowns (per-service and
   layer-level) hold the workload layer open until that completes — see
   §Cloud Run egress.
3. **PSA peering lock.** GCP holds a Private Service Access lock for several
   minutes after subnet deletion. The 600s buffer handles this:

```
workload destroy  →  Cloud Run, Cloud SQL, LB, etc. removed
        │
        ▼
  time_sleep (150s ×2)         ← IP-release cooldowns (Direct VPC Egress)
foundation destroy
        │
        ▼
  Private subnet deleted
        │
        ▼
  time_sleep (600s = 10 min)   ← decommissioning_buffer (PSA lock release)
        │
        ▼
  Service Networking Connection deleted (ABANDON policy)
        │
        ▼
  PSA IP range deleted  →  VPC Network deleted
```

**Expected foundation destroy duration: ~10–12 minutes**, dominated by the PSA
buffer. The workload layer adds ~150s for the IP-release cooldowns.

---

## Module Inventory

```
modules/
├── foundation/
│   ├── vpc/                  VPC, subnets, PSA range + peering, flow logs, PSA buffer
│   └── cloud_firewall/       Firewall rules
│
└── workload/
    ├── cloud_run_service/    Cloud Run v2 service + Direct VPC Egress + GCS FUSE + secret refs
    ├── cloud_sql/            Cloud SQL (PostgreSQL) private instance
    ├── cloud_storage/        GCS bucket
    ├── https_load_balancer/  Global LB + path routing + managed SSL + HTTP redirect
    ├── cloud_armor/          WAF security policy
    ├── iam_service_account/  Service account + role bindings
    ├── artifact_registry/    Docker image repository
    ├── secret_manager/       Secret + rotation config
    ├── secret_rotation/      Pub/Sub + Cloud Run Job rotation handler
    └── pubsub/               Pub/Sub topic primitive
```

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Compute | Cloud Run v2 (not GKE) | No cluster management, scale-to-zero, lower operational overhead |
| Networking | Direct VPC Egress (not a Serverless VPC Access Connector) | No connector fleet to keep healthy and no idle cost; the price is per-instance IP reservations, handled by the release cooldowns |
| LB routing | Path-based at LB layer | Cloud Armor covers both services; frontend not in request path for API |
| Database access | PSA (not Cloud SQL Auth Proxy) | Lower latency, no sidecar, private IP enforced at network level |
| Secret injection | Secret Manager env var refs | Secrets never in plaintext; versioned + auditable |
| State backend | GCS remote state, per layer + env | Independent layer states; `workload` reads `foundation` via `terraform_remote_state` |
| Layering | Two independent roots (no root orchestrator) | Smaller blast radius; deploy `workload` without touching networking |
| CI/CD | GitHub Actions (test, security-scan, plan, deploy, destroy) | Plan-on-PR, manual gated apply, confirmed destroy, per-layer selection |
| CI auth | Workload Identity Federation (keyless) | No long-lived SA keys in GitHub; per-env pool + deployer SA (see `bootstrap/`) |
| Ingress default | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Secure by default; services must explicitly opt into LB exposure |
