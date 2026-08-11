# Design: variante GKE Standard da plataforma (exercício de arquitetura)

> Como ficaria a mesma aplicação (frontend + backend API + PostgreSQL) trocando Cloud Run por **GKE Standard**, mantendo a postura de segurança e o modelo multi-ambiente. Material de entrevista.

---

## Princípio que guia o design
**Terraform provisiona a plataforma; GitOps entrega as aplicações.** A fronteira é deliberada: o que tem ciclo de vida de *infra* (rede, cluster, banco) é Terraform; o que tem ciclo de vida de *release* (Deployments, Services, Ingress) é Helm/Kustomize reconciliado por ArgoCD.

---

## Diagrama

```
                          Internet
                             │
                   ┌─────────▼─────────┐
                   │   Cloud Armor WAF │  (OWASP, rate limit, DDoS)
                   └─────────┬─────────┘
                   ┌─────────▼──────────────┐
                   │ Global HTTPS LB        │  ← provisionado pelo GKE Gateway API
                   │ (Gateway + GCPBackend  │     (não mais URL map em Terraform puro)
                   │  Policy → Cloud Armor) │
                   └─────────┬──────────────┘
                             │ /api → backend Svc   |  /* → frontend Svc
          ┌──────────────────▼───────────────────────────────┐
          │  GKE Standard — cluster privado, regional, VPC-native │
          │                                                   │
          │   ns: frontend         ns: backend                │
          │   Deployment+HPA       Deployment+HPA             │
          │   KSA──Workload Identity──▶ GSA (PoLP)            │
          │                          │ External Secrets / CSI │
          │   Dataplane V2 + NetworkPolicy                    │
          └───────────┬───────────────────────┬──────────────┘
                      │ pods na VPC (alias IP) │ PSA peering
          ┌───────────▼───────┐     ┌──────────▼─────────────┐
          │ Cloud NAT (egress) │     │ Cloud SQL (private IP) │
          └────────────────────┘     └────────────────────────┘

   Entrega de apps:  Git (charts/overlays) ──▶ ArgoCD (pull/reconcile) ──▶ cluster
   Observabilidade:  kube-prometheus-stack (Prometheus/Grafana/Alertmanager) + Cloud Logging
```

---

## Camadas (state topology)

```
foundation/   (Terraform)  VPC VPC-native, subnet de nodes + 2 secondary ranges
                           (pods, services), firewall, Cloud NAT, PSA peering
cluster/      (Terraform)  GKE Standard privado + node pools + Workload Identity
                           + bootstrap de plataforma (ArgoCD, ingress/gateway,
                           external-secrets, kube-prometheus) via Helm provider
data/         (Terraform)  Cloud SQL, Artifact Registry, Secret Manager,
                           Cloud Armor policy, GCS
apps/         (GitOps)     Deployments/Services/HPA/Gateway via Helm + Kustomize,
                           reconciliados pelo ArgoCD — NÃO é Terraform
```

Encadeamento por `terraform_remote_state`: `cluster` lê outputs de `foundation` (rede/ranges); `data`/`apps` leem o endpoint do cluster e o connection name do SQL. Mesma disciplina de "outputs = API versionada" do projeto original.

> **Por que separar `cluster` de `foundation`:** o cluster tem ciclo de vida próprio (upgrades, troca de node pool) bem mais ágil que a rede base. Misturar = replanejar VPC a cada mudança de node pool.

---

## Mudanças concretas vs. o projeto Cloud Run

| Tema | Some / muda | Entra |
|---|---|---|
| Egress | VPC Access Connector **removido** | Cluster VPC-native (alias IP); Cloud NAT p/ egress dos nodes privados |
| Compute | módulos `cloud_run_service` **removidos** | GKE cluster + node pools (TF) + Deployments (Helm/Kustomize) |
| LB / routing | URL map 100% Terraform | **Gateway API** (K8s) provisiona o LB; Cloud Armor via `GCPBackendPolicy` |
| Identidade | SA por serviço (nativo) | **Workload Identity** (KSA→GSA) |
| Secrets | secret refs nativas | **External Secrets Operator** ou Secret Manager **CSI** |
| Autoscaling | request-based, scale-to-zero | **HPA** (pods) + **Cluster Autoscaler** (nodes); KEDA se quiser scale-to-zero |
| Observabilidade | métricas nativas | **kube-prometheus-stack** (ou Google Managed Prometheus) |
| Entrega | `terraform apply` | **ArgoCD** (pull/GitOps) + Helm/Kustomize |
| DB | PSA (igual) | PSA igual, ou Cloud SQL Auth Proxy sidecar |

---

## Decisões-chave e trade-offs (a parte que impressiona)

| Decisão | Escolha | Por quê / trade-off |
|---|---|---|
| Standard vs Autopilot | **Standard** | Controle total de node pools/custos; Autopilot tira ops mas tira controle (taints, DaemonSets, GPU) |
| Cluster privado | **Sim** | Nodes sem IP público; control plane com endpoint privado + authorized networks; exige Cloud NAT p/ egress |
| Gateway API vs Ingress | **Gateway API** | Modelo mais novo, multi-backend, separação infra/rota; Ingress é mais simples mas legado |
| Helm vs Kustomize | **Ambos** | Helm p/ empacotar/3rd-party (ArgoCD, prometheus); Kustomize overlays p/ diferença hml/prod sem templating |
| GitOps (ArgoCD) vs push CI/CD | **ArgoCD (pull)** | Reconciliação contínua por estado desejado, drift detection; CI só builda imagem + bumpa tag no Git |
| Secrets: ESO vs CSI | **External Secrets Operator** | Sincroniza Secret Manager → K8s Secret; CSI monta direto (sem objeto Secret) — escolha por necessidade de auditoria/rotação |
| NetworkPolicy | **Dataplane V2 (Cilium)** | Microssegmentação pod-a-pod; PoLP a nível de rede |

---

## Como a segurança evolui (defense in depth no K8s)
- **Borda:** Cloud Armor no LB (igual).
- **Rede:** cluster privado + Cloud NAT + **NetworkPolicy** (Dataplane V2) entre namespaces.
- **Identidade:** Workload Identity (sem chave de SA no pod) + **RBAC** mínimo por namespace.
- **Workload:** **Pod Security Standards** (restricted), read-only rootfs, non-root, **Binary Authorization** (só imagens assinadas).
- **Supply chain:** Trivy agora escaneia **imagens + manifests K8s**, não só Terraform.
- **Secrets:** Secret Manager como fonte; ESO/CSI; rotação.

---

## Teardown muda de natureza
Some o problema de IP-release do connector. Entram:
- **drain de node pools** antes de destruir;
- **PV/Persistent Disks** podem ficar órfãos (deletar PVCs / `reclaimPolicy`);
- **deletar o cluster com Ingress/Gateway vivo órfã o LB** (finalizers) — ordem: remover apps (ArgoCD) → cluster → rede.

Ordem de destroy: `apps (ArgoCD prune) → data → cluster → foundation`.

---

## Mapeamento direto com o JD da vaga
| Requisito/diferencial | Onde aparece nesta arquitetura |
|---|---|
| Kubernetes (CKA) | Operação do cluster, RBAC, NetworkPolicy, HPA |
| Helm / Kustomize | Empacotamento + overlays por ambiente |
| GitOps | ArgoCD pull-based, drift detection |
| Prometheus | kube-prometheus-stack |
| Terraform/IaC | foundation/cluster/data layers |
| GCP | GKE, VPC-native, PSA, Cloud Armor, Workload Identity |
| Anthos | a um passo (GKE + multi-cluster/multi-cloud) |
| Docker | imagens + Binary Authorization |

---

## Frase de fechamento (entrevista)
> "A versão Cloud Run otimiza custo operacional para um app stateless. A versão GKE Standard troca isso por controle e portabilidade: Terraform provisiona rede → cluster → dados, e as aplicações são entregues por GitOps (ArgoCD) com Helm/Kustomize. O connector dá lugar a um cluster VPC-native com Cloud NAT, o LB vira Gateway API com Cloud Armor via GCPBackendPolicy, e a identidade migra pra Workload Identity. Cada decisão tem o trade-off explícito — é a mesma engenharia, otimizando para variáveis diferentes."
