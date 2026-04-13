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
                                          │  │  10.0.0.0/20                    │   │
                                          │  │  Direct VPC Egress IPs live here│   │
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

The project uses a **strictly isolated two-layer architecture**. Each layer is a separate Terraform root module with its own state. The root `main.tf` orchestrates both by passing foundation outputs as workload inputs.

```
root main.tf
├── module "foundation"  →  ./foundation/
└── module "workload"    →  ./workload/          (depends_on: foundation)
```

### Layer 1 — Foundation (Core Networking)

**Location:** `foundation/`

Owns the base networking environment. Nothing application-specific lives here. The foundation must exist before any workload resource can be created, and must outlive all workload resources during teardown.

| Resource | Module | Purpose |
|----------|--------|---------|
| VPC Network | `modules/foundation/vpc` | Custom VPC, no auto-subnets |
| Private Subnet | `modules/foundation/vpc` | `10.0.0.0/20` — Cloud Run Direct VPC Egress |
| Secondary Subnet | `modules/foundation/vpc` | Reserved for future use |
| PSA IP Range | `modules/foundation/vpc` | `/16` at `172.21.0.0` — Cloud SQL private connectivity |
| Service Networking Connection | `modules/foundation/vpc` | Peering for managed services (Cloud SQL) |
| Firewall Rules | `modules/foundation/cloud_firewall` | Allow ports 443 + 8080 from RFC-1918 |
| VPC Flow Logs | `modules/foundation/vpc` | Full metadata logging on private subnet |
| Terraform State Bucket | `foundation/state_bucket.tf` | GCS bucket for remote state |

### Layer 2 — Workload (Compute & Data)

**Location:** `workload/`

Owns everything application-specific. Consumes VPC outputs from foundation (`vpc_network_id`, `private_subnet_id`, `psa_connection_id`) as inputs.

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

## Destroy Orchestration

Tearing down this infrastructure is non-trivial due to GCP's asynchronous resource release behavior. Three timing guards are in place:

```
terraform destroy
        │
        ▼
  Cloud Run services destroyed
        │   (Direct VPC Egress IPs are reserved internally by GCP)
        ▼
  time_sleep (150s per service + 150s workload guard)
        │   (waits for GCP to release Direct VPC Egress IP reservations)
        ▼
  Private subnet deleted
        │
        ▼
  time_sleep (600s = 10 min)
        │   (GCP PSA lock release after subnet deletion)
        ▼
  Service Networking Connection deleted (ABANDON policy)
        │
        ▼
  PSA IP range deleted
        │
        ▼
  VPC Network deleted
```

**Expected destroy duration: 15–25 minutes** due to the timing guards.

**Important:** If Cloud Run services are deleted outside of the normal Terraform flow (e.g., via `gcloud run services delete`), the VPC Egress IP reservations may persist for 10–30 minutes and block subnet deletion. This is a GCP-internal behavior and cannot be bypassed programmatically.

---

## Module Inventory

```
modules/
├── foundation/
│   ├── vpc/                  VPC, subnets, PSA range + peering, flow logs, teardown timers
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
| Networking | Direct VPC Egress (not VPC Connector) | Higher throughput, no connector bottleneck |
| LB routing | Path-based at LB layer | Cloud Armor covers both services; frontend not in request path for API |
| Database access | PSA (not Cloud SQL Auth Proxy) | Lower latency, no sidecar, private IP enforced at network level |
| Secret injection | Secret Manager env var refs | Secrets never in plaintext; versioned + auditable |
| State backend | GCS remote state | Shared state for team; versioning enabled |
| Ingress default | `INGRESS_TRAFFIC_INTERNAL_ONLY` | Secure by default; services must explicitly opt into LB exposure |
