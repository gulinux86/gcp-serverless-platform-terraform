# Architecture

A private GKE Standard platform for a two-tier web application (frontend + backend API + PostgreSQL). **Terraform provisions the platform; Argo CD delivers the workloads.** The boundary is deliberate: what has an infrastructure lifecycle (network, cluster, database, identities, IP/WAF/certificates) is Terraform; what has a release lifecycle (Deployments, Services, Gateway routes, add-ons) is Git, reconciled by Argo CD.

The pipelines, the layer contract and the Argo CD handover are ported from [`eks-terraform`](../eks-terraform); this document notes where GKE changes the design.

---

## Diagram

```
                              Internet
                                 │
                     ┌───────────▼────────────┐
                     │  Static global IP (TF) │◀── networking.gke.io/addresses
                     └───────────┬────────────┘
                     ┌───────────▼────────────┐
                     │ Cloud Armor policy (TF)│◀── GCPBackendPolicy (Git)
                     └───────────┬────────────┘
                     ┌───────────▼────────────────────────┐
                     │ Global External Application LB     │  built by the GKE Gateway
                     │ Gateway + HTTPRoute (Git)          │  controller from Git
                     │  /api → backend   /* → frontend    │
                     └───────────┬────────────────────────┘
                                 │ container-native NEGs (pod IPs)
 ┌───────────────────────────────▼─────────────────────────────────────────────┐
 │ VPC  app-<env>-vpc                                                          │
 │  node subnet 10.0.0.0/22 ── pods 10.4.0.0/16 ── services 10.8.0.0/20        │
 │                                                                             │
 │  ┌───────────────────────────────────────────────────────────────────────┐  │
 │  │ GKE Standard  app-<env>-gke   (private nodes, private IP endpoint)    │  │
 │  │                                                                       │  │
 │  │  argocd ── root Application ──▶ gke-gitops-platform-apps (via NAT)    │  │
 │  │  external-secrets ──WI──▶ external-secrets-sa ──▶ Secret Manager      │  │
 │  │  backend-<env>  ──WI──▶ backend-sa ──▶ Cloud SQL (Auth Proxy) / GCS   │  │
 │  │  frontend-<env> ──WI──▶ frontend-sa                                   │  │
 │  │  Dataplane V2 (NetworkPolicy) · Managed Prometheus · shielded nodes   │  │
 │  └──────────────┬─────────────────────────────────────┬──────────────────┘  │
 │                 │ egress                               │ PSA peering         │
 │       ┌─────────▼─────────┐               ┌────────────▼────────────┐        │
 │       │ Cloud Router + NAT│               │ Cloud SQL (private IP)  │        │
 │       └───────────────────┘               └─────────────────────────┘        │
 └─────────────────────────────────────────────────────────────────────────────┘

  Control plane access from outside the VPC:
    GitHub Actions / operator ──(Google OAuth token, IAM: container.clusters.connect)──▶
    DNS endpoint  gke-<hash>.<region>.gke.goog   (IP endpoint stays internal)
```

---

## Layers

Two independent root modules, per-environment state, no orchestrator — the same shape as before and as `eks-terraform`.

```
bootstrap/   local state, owner-run once per env: APIs, WIF pool/provider,
             tf-plan-<env> (read-only) and tf-deployer-<env> service accounts
foundation/  gs://serverless-<env>/<env>/foundation
             VPC + secondary ranges, firewall, Cloud NAT, PSA, node SA,
             GKE cluster, node pool
workload/    gs://serverless-<env>/<env>/workload
             Cloud SQL, Secret Manager, Artifact Registry, GCS, audit sink,
             alert policies, Workload Identity GSAs, static IP, Cloud Armor,
             managed cert, Argo CD, Argo CD bootstrap (AppProjects + root app)
GitOps repo  gke-gitops-platform-apps — everything inside the cluster after
             the root Application. Not Terraform.
```

**Why the cluster is in `foundation` and Argo CD in `workload`.** Same split as `eks-terraform`: the cluster is the substrate every in-cluster resource depends on, and the Helm provider can only be configured from values that exist before the plan starts. Putting the cluster and the Helm releases in one root makes the provider depend on a resource in the same plan — the well-known chicken-and-egg. Reading the endpoint from foundation's remote state removes it.

### Layer contract

The workload reads five foundation outputs through `terraform_remote_state`: `vpc_network_id`, `psa_connection_id`, `cluster_name`, `cluster_dns_endpoint`, `workload_identity_pool`. That link exists only at run time — a renamed output passes fmt, validate, every module suite and Trivy, and fails during a workload apply. `scripts/check-layer-contract.sh` compares the referenced names with `foundation/outputs.tf`, credential-free, in `terraform-test` and in the deploy gate. `terraform-plan` derives the same list to decide whether foundation's state is complete enough to plan the workload.

---

## Control plane access

The cluster is private on both sides: nodes have no external IP, and the control plane's IP endpoint is internal (`enable_private_endpoint = true`, no GCP-public CIDRs authorised). Something still has to install Argo CD from a GitHub-hosted runner, which has no stable IP and no route into the VPC.

| Option | Why not / why |
|---|---|
| Public IP endpoint + authorised networks | Runner IPs are unpredictable; the allowlist degenerates to `0.0.0.0/0` |
| Bastion / IAP tunnel (the `eks-terraform` approach: bastion + SSM) | Works, but adds a VM, its patching, and tunnel plumbing in every pipeline step |
| Self-hosted runner inside the VPC | Another fleet to operate and secure |
| **DNS-based endpoint** | **Chosen.** Reachable from anywhere, authorised per request by IAM (`container.clusters.connect`) with the caller's Google token. No IP allowlist, no extra infrastructure; served with a publicly trusted certificate |

Consequences:

- The Helm provider is configured with `host = https://<dns endpoint>` and an OAuth token from `google_client_config` — no CA certificate.
- Operators use `gcloud container clusters get-credentials … --dns-endpoint`.
- Revoking an identity's IAM role revokes its cluster access; there is no network-level credential to rotate.

---

## GitOps handover

```
terraform (workload)                         Argo CD (from Git)
────────────────────                         ──────────────────
helm_release.argocd        CRDs + controllers
helm_release.bootstrap ─┬─ AppProject platform   (cluster-scoped allowed, enumerated sourceRepos)
                        ├─ AppProject apps       (namespaces frontend-*/backend-*, no cluster resources,
                        │                         no ClusterRole/ClusterRoleBinding)
                        └─ Application root ───▶ bootstrap/apps/  ──▶ namespaces, cert-manager, ESO,
                                                                       kube-prometheus-stack, platform
                                                                       config (Gateway, HTTPRoute,
                                                                       GCPBackendPolicy), microservices
                                                                       ApplicationSet
```

- **Why a local Helm chart for the bootstrap.** `kubernetes_manifest` needs the CRD schema at *plan* time; on a first apply Argo CD's CRDs do not exist yet. Helm hands manifests over at apply time.
- **Why Terraform keeps the AppProjects.** They are the privilege boundary. A boundary stored in the repository it governs can be widened by anyone who can commit to it.
- **Gateway API CRDs are GKE's.** `gateway_api_config` makes GKE install and upgrade them; `github.com/kubernetes-sigs/gateway-api` is deliberately not in `platform_source_repos`, so an Application trying to install them is refused instead of fighting GKE.
- **The boundary only binds Applications that use it.** Argo CD always has a permissive `default` project. Child Applications must declare `project: platform` or `project: apps`; one that says `project: default` bypasses both lists above.

---

## Edge

The load balancer moved from Terraform (URL map, backend services, serverless NEGs) to Git (Gateway + HTTPRoute), built by the GKE Gateway controller. Terraform keeps the pieces that are security policy or must survive a re-sync, and exports their **names**:

| Terraform | Referenced from Git by |
|---|---|
| `google_compute_global_address.gateway` | `networking.gke.io/addresses` annotation |
| `module.cloud_armor` | `GCPBackendPolicy.spec.default.securityPolicy` |
| `google_compute_managed_ssl_certificate.gateway` (with `domain_name`) | `networking.gke.io/pre-shared-certs` |

Trade-off: the LB is outside Terraform state, so `terraform destroy` does not know it exists. The teardown handles that explicitly (below). `eks-terraform` went the other way after four failed destroys — it moved the ALB *into* Terraform and binds pods to it with a TargetGroupBinding. GKE has no supported equivalent for a Gateway-built LB, and its controller is managed by Google in the control plane (it cannot be uninstalled before the Gateway is gone), so draining while the cluster is alive is reliable here.

---

## Identity

| Identity | How it is reached | Can do |
|---|---|---|
| `<name>-gke-nodes` | node VM | write logs/metrics, pull from Artifact Registry |
| `backend-sa` | KSA `backend-<env>/backend-<env>` (WI) | Cloud SQL client, app bucket objects, `app-api-key` |
| `frontend-sa` | KSA `frontend-<env>/frontend-<env>` (WI) | nothing (own identity, not the node's) |
| `external-secrets-sa` | KSA `external-secrets/external-secrets` (WI) | read `app-api-key`, `db-password` |
| `tf-plan-<env>` | any workflow of this repo (WIF, `attribute.repository`) | read project + state |
| `tf-deployer-<env>` | jobs with `environment: <env>` only (WIF, `attribute.environment`) | apply/destroy |

The plan/deploy split mirrors `eks-terraform`'s plan and deploy roles. `terraform-plan` runs on pull requests with the workflow file from the PR's branch, so it must not be able to reach a writing identity. GitHub only adds the `environment` claim to jobs that declare an Environment, and the Environment's protection rules gate those jobs; the WIF provider maps the missing claim to `none`, which matches no binding.

The plan SA has no Kubernetes access worth the name, so the workload plan runs with `-refresh=false` (Helm releases are planned from stored state; drift shows at deploy time) and every plan runs with `-lock=false` (the GCS lock would need write access).

---

## Secrets

Secret Manager stays the source of truth. External Secrets Operator syncs `db-password` into a Kubernetes Secret consumed by the backend; `backend-sa` can still read `app-api-key` directly.

Automatic rotation is **not** wired any more. The previous design (Secret Manager rotation → Pub/Sub push → Cloud Run Job) never worked — the push sent an OIDC token to an API that only accepts OAuth — and its handler was a Cloud Run placeholder. A GKE-native replacement (a CronJob or an Argo Workflow that adds a version and lets ESO's `refreshInterval` pick it up) belongs in the GitOps repository.

---

## Environments

| | hml | prod |
|---|---|---|
| Cluster location | `us-central1-a` (zonal, free-tier control plane) | `us-central1` (regional) |
| Release channel | REGULAR | STABLE |
| Nodes | `e2-standard-2`, on-demand, 1–3 | `e2-standard-4`, on-demand, 1–3 per zone |
| Cluster `deletion_protection` | false | true |
| Audit bucket `force_destroy` | true | false |

---

## Teardown

What changed against the Cloud Run version: the serverless IP-release gate (up to 2h waiting for `purpose=SERVERLESS` reservations) is gone. What GKE adds is cluster-owned cloud resources that Terraform does not know about:

| Resource | Created by | Blocks | Handled by |
|---|---|---|---|
| Global LB (forwarding rule, proxy, URL map, backend services) | Gateway controller | static IP delete (workload) | Drain: delete Applications/Gateways, wait for the forwarding rule on the IP to go |
| Zonal NEGs | NEG controller | node subnet delete | Sweep after the cluster is destroyed |
| `gke-*` / `k8s-*` / `gkegw1-*` firewall rules | GKE | VPC delete | Mostly removed with the cluster; sweep the rest by prefix, never a rule in state |
| PVC persistent disks | PD CSI driver | nothing (cost only) | Reported, never deleted |

Order in `terraform-destroy` (`layer: both`):

1. **Drain** (cluster alive): freeze Argo CD automation parents-first; delete ApplicationSets, then Applications; strip stuck finalizers; delete leftover Gateways, Ingresses and `LoadBalancer` Services; wait for no forwarding rule on the static IP.
2. **Destroy workload** — uninstalls Argo CD through the still-running cluster, then data, identities, IP.
3. **Preflight** — any `gkegw1-*`/`k8s1-*`/`k8s2-*` backend service or URL map left fails the run in seconds.
4. **Destroy foundation in passes** — `-target` node pool + cluster; sweep NEGs and GKE firewall rules in the VPC (VPC and Terraform-owned rule names read from state, not outputs); destroy the rest, including the 10-minute PSA buffer.
5. **Report** unattached PVC disks.

Freezing uses `syncPolicy.automated = null`, not scaling the application controller to zero: the controller is what processes the finalizers the deletion waits on.

---

## Module inventory

| Module | Purpose | Tests |
|---|---|---|
| `foundation/vpc` | VPC, node subnet + secondary ranges, flow logs, PSA | ✓ |
| `foundation/cloud_firewall` | Internal allow rule (+ optional deny-all) | ✓ |
| `foundation/cloud_nat` | Router + NAT, node subnet only | ✓ |
| `foundation/gke_cluster` | Private GKE Standard | ✓ |
| `foundation/gke_node_pool` | Hardened node pool | ✓ |
| `workload/iam_service_account` | SA, project roles, Workload Identity bindings | ✓ |
| `workload/argocd` | Argo CD Helm release | ✓ |
| `workload/argocd_bootstrap` | AppProjects + root Application | ✓ |
| `workload/cloud_sql` | PostgreSQL, private IP, TLS | ✓ |
| `workload/cloud_armor` | WAF policy | ✓ |
| `workload/secret_manager` | Secret + version | — |
| `workload/cloud_storage` | Bucket | — |
| `workload/artifact_registry` | Docker repository | — |
