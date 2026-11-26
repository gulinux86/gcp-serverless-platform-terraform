# GCP Platform — Private GKE + Argo CD (Terraform)

Two-tier web application (frontend + backend API + managed PostgreSQL) on **GKE Standard**: a private, VPC-native cluster with Workload Identity and Dataplane V2, bootstrapped with **Argo CD** so every Kubernetes workload is delivered by GitOps. Terraform provisions the platform; Argo CD delivers what runs on it. Two independent Terraform layers, per-environment state (`hml`/`prod`), and a GitHub Actions pipeline with keyless (WIF) auth and a read-only plan identity — ported from [`eks-terraform`](../eks-terraform).

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full diagram, the Terraform/GitOps boundary, and the teardown design.

> **History.** This repository started as a Cloud Run platform (Cloud Run v2 + Direct VPC Egress + Terraform-managed URL map). The Cloud Run services, the serverless LB, the Pub/Sub + Cloud Run Job secret rotation, and the serverless IP-release gate are gone. The posts under `docs/blog-*` describe that earlier design.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Terraform | 1.17.2 in CI (`>= 1.7.0` in code) | module tests use `mock_provider` |
| gcloud CLI + `gke-gcloud-auth-plugin` | recent | `gcloud components install gke-gcloud-auth-plugin kubectl` |
| Google provider | `>= 6.14.0` (locked at 7.x) | DNS-based control-plane endpoint |
| Helm provider | `~> 2.17` | `set {}` block syntax |

```bash
gcloud auth application-default login
gcloud config set project <project-id>
```

---

## Project Structure

```
.
├── .github/
│   ├── actions/gcp-terraform-setup/  # WIF auth (plan|deploy identity) + Terraform (+ kubectl)
│   └── workflows/                    # plan, deploy, destroy, test, security-scan, lint, docs
│                                     # + reusable _terraform-test/_terraform-validate/_security-scan
├── bootstrap/                  # One-time, owner-run: APIs, WIF pool, plan SA (RO) + deployer SA
├── foundation/                 # Layer 1: VPC-native network, NAT, private GKE cluster, node pool
├── workload/                   # Layer 2: Cloud SQL, secrets, WI identities, edge (IP/WAF/cert), Argo CD
├── scripts/check-layer-contract.sh  # foundation outputs ⇄ workload references, credential-free
└── modules/
    ├── foundation/
    │   ├── vpc/                # VPC, node subnet + pod/service secondary ranges, PSA peering
    │   ├── cloud_firewall/     # Internal firewall rules
    │   ├── cloud_nat/          # Router + NAT scoped to the node subnet
    │   ├── gke_cluster/        # Private GKE Standard (DNS endpoint, WI, Dataplane V2, Gateway API)
    │   └── gke_node_pool/      # Hardened node pool (dedicated SA, GKE_METADATA, shielded, surge)
    └── workload/
        ├── argocd/             # Argo CD Helm release (bare: CRDs + controllers)
        ├── argocd_bootstrap/   # AppProjects + root Application (local Helm chart)
        ├── iam_service_account/# SA + role bindings + Workload Identity bindings
        ├── cloud_sql/          # PostgreSQL, private IP only
        ├── cloud_armor/        # WAF policy (attached from Git via GCPBackendPolicy)
        ├── secret_manager/ · cloud_storage/ · artifact_registry/
```

The Kubernetes side lives in the GitOps repository **[`gke-gitops-platform-apps`](../gke-gitops-platform-apps)**: platform add-ons (External Secrets, cert-manager, kube-prometheus-stack), the Gateway/HTTPRoute/GCPBackendPolicy, and the frontend/backend Helm charts.

---

## Architecture in one screen

```
foundation/  ── apply ──▶ gs://serverless-<env>/<env>/foundation
  VPC (nodes /22, pods /16, services /20) · Cloud NAT · PSA
  GKE Standard: private nodes + private IP endpoint + IAM-authorised DNS endpoint
  node pool (dedicated SA, Workload Identity metadata)
                                │ terraform_remote_state
workload/    ── apply ──▶ gs://serverless-<env>/<env>/workload
  Cloud SQL (PSA) · Secret Manager · Artifact Registry · GCS · audit sink · alerts
  GSAs ⇄ KSAs (Workload Identity) · static IP + Cloud Armor + managed cert
  Argo CD ──▶ AppProjects + root Application ──▶ gke-gitops-platform-apps
```

| Decision | Choice | Rationale |
|---|---|---|
| Compute | GKE **Standard** | Node pools, DaemonSets and taints under our control; Autopilot trades that for less ops |
| Cluster exposure | Private nodes **and** private IP endpoint | Nothing in the cluster has a public IP |
| Control-plane access from CI | **DNS-based endpoint**, IAM-authorised | GitHub runners have no stable IP and no path into the VPC; no bastion, no `0.0.0.0/0` allowlist |
| Delivery | **Argo CD** app-of-apps | Terraform stops at one root Application; Git is the only way to change the cluster |
| Edge | GKE **Gateway API** (in Git) + Terraform-owned IP/WAF/cert | Routing is release-lifecycle (Git); IP, WAF and certs are infra-lifecycle (Terraform) |
| Workload identity | **Workload Identity** KSA → GSA | No SA keys in pods; per-workload least privilege |
| Secrets | Secret Manager → **External Secrets Operator** | Source of truth stays in Secret Manager; ESO's GSA reads only the listed secrets |
| Egress | **Cloud NAT** scoped to the node subnet | Private nodes still pull public images and reach GitHub |
| Environments | hml: zonal cluster, smaller on-demand nodes; prod: regional, larger on-demand nodes | Free-tier control plane where a zone outage is acceptable; no Spot preemptions in either |
| CI identities | read-only **plan** SA vs **deployer** SA bound to the GitHub `environment` claim | A PR can plan but can never mint a token that writes |

---

## Usage

### First-time setup

**1. State bucket** (must exist before `init`; intentionally **not** managed by Terraform). One per env:
```bash
gcloud storage buckets create gs://serverless-hml \
  --location=US-CENTRAL1 --uniform-bucket-level-access --project=<project-id>
gcloud storage buckets update gs://serverless-hml --versioning
```
> Bucket names are global. If `serverless-hml` is taken, change it in `foundation|workload/environments/<env>/backend.hcl` and `workload/environments/<env>/terraform.tfvars` (`state_bucket`), and in `bootstrap/main.tf` (`local.state_bucket`).

**2. Bootstrap** (once per environment, owner credentials). Enables the APIs, creates the WIF pool, the read-only plan SA and the deployer SA:
```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply \
  -var-file=environments/hml/terraform.tfvars \
  -var="project_id=<your-hml-project-id>"
```

**3. GitHub configuration** (per env — nothing project-identifying is committed):

| Secret | Value |
|---|---|
| `HML_PROJECT_ID` / `PROD_PROJECT_ID` | GCP project id → `TF_VAR_project_id` |
| `HML_WIF_PROVIDER` / `PROD_WIF_PROVIDER` | bootstrap output `workload_identity_provider` |
| `HML_PLAN_SA` / `PROD_PLAN_SA` | bootstrap output `plan_service_account` (read-only) |
| `HML_WIF_SA` / `PROD_WIF_SA` | bootstrap output `deployer_service_account` |
| `HML_DB_PASSWORD` / `PROD_DB_PASSWORD` | `TF_VAR_db_password` |
| `HML_API_SECRET_KEY` / `PROD_API_SECRET_KEY` | `TF_VAR_api_secret_key` |

Create the GitHub Environments **`hml`** and **`prod`** — the deployer SA only accepts tokens from jobs that declare one of them. Put a required reviewer and a deployment-branch policy on `prod`.

**4. Deploy** via `terraform-deploy` (`environment`, `layer: both`). Locally:
```bash
ENV=hml
export TF_VAR_project_id=<project-id> TF_VAR_db_password=... TF_VAR_api_secret_key=...

terraform -chdir=foundation init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=foundation apply -var-file=environments/$ENV/terraform.tfvars

terraform -chdir=workload init -backend-config=environments/$ENV/backend.hcl
terraform -chdir=workload apply -var-file=environments/$ENV/terraform.tfvars
```

**5. Reach the cluster and Argo CD**
```bash
$(terraform -chdir=foundation output -raw get_credentials_command)   # --dns-endpoint
kubectl -n argocd port-forward svc/argocd-server 8080:443            # https://localhost:8080
$(terraform -chdir=workload output -raw argocd_initial_password_command)
```

**6. Wire the GitOps repo to this layer's outputs.** The Gateway and GCPBackendPolicy reference Terraform-owned objects by name:

| GitOps field | Terraform output |
|---|---|
| Gateway annotation `networking.gke.io/addresses` | `gateway_address_name` |
| Gateway option `networking.gke.io/pre-shared-certs` | `gateway_certificate_name` (needs `domain_name`) |
| GCPBackendPolicy `spec.default.securityPolicy` | `cloud_armor_policy_name` |
| KSA annotation `iam.gke.io/gcp-service-account` | `backend_sa_email`, `frontend_sa_email`, `external_secrets_sa_email` |
| ClusterSecretStore `clusterName` / `clusterLocation` | foundation `cluster_name` / `cluster_location` |
| backend `cloudSqlProxy.instanceConnectionName` | `database_connection_name` |

The KSA names Workload Identity trusts are set in `workload/environments/<env>/terraform.tfvars` (`backend_ksas`, `frontend_ksas`, `external_secrets_ksas`).

### Destroy

`terraform-destroy` with `layer: both` handles the ordering GKE needs (ARCHITECTURE.md §Teardown):

1. **Drain** — freeze Argo CD automation, delete ApplicationSets and Applications (cascade removes the Gateway), delete leftover Gateways/Ingresses/LoadBalancer Services, wait until no forwarding rule holds the static IP.
2. **Destroy workload** — Argo CD, data, identities, static IP.
3. **Preflight** — fail fast if a GKE-built backend service/URL map is still around.
4. **Destroy foundation** — node pool + cluster first, sweep NEGs and GKE firewall rules left in the VPC, then the rest (the PSA buffer still waits ~10 min).
5. Report unattached PVC disks (not deleted).

`prod` has `deletion_protection = true` on the cluster: its destroy stops at step 4 until that is turned off in a reviewed change. The prod audit-log bucket is not force-destroyed either.

---

## CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| `terraform-test` | PR | Every module with a `tests/` dir (discovered, not listed) + layer-contract check |
| `security-scan` | PR | Trivy IaC scan (Terraform + Helm), fails on HIGH/CRITICAL, uploads SARIF |
| `lint` | PR | actionlint + shellcheck (pinned with checksums) |
| `terraform-docs` | PR | Module READMEs must match their variables/outputs |
| `terraform-plan` | PR + dispatch | Credential-free validate, then plan per layer with the **read-only plan SA** (`-lock=false`, workload `-refresh=false`); posted as a PR comment |
| `terraform-deploy` | manual | Gates (tests, validate, Trivy) → **deployer SA** → saved plan → apply |
| `terraform-destroy` | manual | Typed confirmation → drain → workload → preflight → foundation in passes |

Reusable `_terraform-test`, `_terraform-validate` and `_security-scan` are called by both the PR checks and the deploy gate, so they cannot drift apart. Credential selection lives once, in `.github/actions/gcp-terraform-setup`.

---

## Security Model

1. **Edge** — Cloud Armor (OWASP CRS, rate limiting, Adaptive Protection) attached to the Gateway's backend services through `GCPBackendPolicy`.
2. **Network** — private nodes, private IP endpoint, no GCP-public CIDRs authorised; egress only through NAT scoped to the node subnet; NetworkPolicy enforced by Dataplane V2.
3. **Control plane** — external access only through the DNS endpoint, authorised by IAM per request; no client certificates.
4. **Identity** — dedicated node SA (`roles/container.defaultNodeServiceAccount` + Artifact Registry reader); pods use Workload Identity, bound per `namespace/ksa`.
5. **Database** — Cloud SQL private IP only (PSA), TLS enforced, `backend-sa` holds `cloudsql.client`.
6. **Secrets** — Secret Manager; ESO's GSA has accessor on the listed secrets only. Initial values come from `TF_VAR_*` and **are** in Terraform state — protect the state bucket.
7. **GitOps boundary** — the `apps` AppProject cannot create cluster-scoped resources, ClusterRoles or ClusterRoleBindings, and only deploys to `frontend-*` / `backend-*`.
8. **Audit** — `cloudaudit.googleapis.com` logs exported to GCS, 365-day retention.

| Service account | Grants | Scope |
|---|---|---|
| `<name>-gke-nodes` | `container.defaultNodeServiceAccount`, `artifactregistry.reader` | Project |
| `backend-sa` | `cloudsql.client`; `storage.objectUser`; `secretAccessor` | Project; app bucket; `app-api-key` |
| `frontend-sa` | — (identity only) | — |
| `external-secrets-sa` | `secretAccessor` | `app-api-key`, `db-password` |
| `tf-plan-<env>` | `viewer`, `iam.securityReviewer`, state `objectViewer` | Project; state bucket |
| `tf-deployer-<env>` | `deployer_roles` in `bootstrap/variables.tf` | Project; state bucket `objectAdmin` |

---

## Troubleshooting

**Workload plan skipped: "foundation layer does not currently publish everything".** Foundation is not applied (or half destroyed) for that env. Apply `layer: foundation` first.

**`terraform-deploy` fails at auth with `Permission 'iam.serviceAccounts.getAccessToken' denied`.** The job's token has no matching `environment` claim. Check that the GitHub Environment exists with the exact name (`hml`/`prod`) and that `bootstrap/` was re-applied after this change.

**Helm provider: `Unauthorized` / `forbidden` reaching the cluster.** The identity needs `container.clusters.connect` (in `roles/container.admin` for the deployer) and the DNS endpoint must allow external traffic (`gke_cluster` default).

**Foundation destroy: `subnetwork ... is already being used by .../networkEndpointGroups/...`.** A NEG survived the cluster. Re-run `terraform-destroy` with `layer: foundation` — the sweep deletes NEGs in the VPC before the subnet.

**State lock: `Error acquiring the state lock`.** Make sure nothing is running, then `terraform force-unlock -force <lock-id>`.
