# Cheat-sheet — Entrevista Senior DevOps (AWS / EKS / Fintech-Crypto)

> Vaga: fintech/crypto global, Senior DevOps. Foco: **AWS, EKS, Terraform, CI/CD, segurança, compliance, reliability**, observability, incident response, mentoria. A vaga otimiza para **SEGURANÇA + COMPLIANCE + CONFIABILIDADE** — lidere por aí.

## Pitch de 30s
"Sou DevOps sênior, foco em AWS e Kubernetes, **CKA**, multi-cloud (AWS + GCP). Projeto âncora: plataforma **EKS 100% em Terraform** — cluster privado com **secrets cifrados via KMS**, **IRSA** (identidade sem chave), rede multi-AZ com VPC endpoints, entregue por 5 pipelines no GitHub Actions com **auth keyless via OIDC**, em 2 camadas (rede/workload) e ambientes hml/prod isolados. Opero workloads com Helm e Kustomize. Para uma crypto, meu foco natural é onde segurança, least-privilege e auditabilidade encontram a operação."

---

## 5 histórias STAR (decore Ação + detalhe)

**1. IRSA — identidade sem chave**
- **S/T:** pods precisavam acessar serviços AWS (S3, ELB) sem credencial embutida.
- **A:** OIDC provider do EKS + IAM roles assumidas por service account (IRSA).
- **R:** zero chave estática em pod; least-privilege por workload.

**2. Envelope encryption de secrets com KMS** *(ouro pra crypto)*
- **S/T:** secrets do K8s ficam em texto no etcd por padrão.
- **A:** `encryption_config` (resources=["secrets"]) com chave KMS dedicada.
- **R:** secrets cifrados em repouso, chave gerenciada/auditável.

**3. CI/CD keyless via OIDC**
- **S/T:** evitar access keys da AWS em secret do GitHub.
- **A:** GitHub Actions assume IAM role via OIDC federation; role por ambiente.
- **R:** nenhuma credencial de longa duração; tokens curtos, rotação automática.

**4. Endpoint EKS privado + exceção controlada pro CI** *(trade-off de sênior)*
- **S/T:** control plane privado, mas runner do GitHub é externo à VPC.
- **A:** mantive `endpoint_private_access`; público restrito por `public_access_cidrs`, documentado no `.trivyignore` com justificativa.
- **R:** operável pelo CI sem abrir mão da postura; exceção rastreável.

**5. Shift-left security (Trivy + terraform test)**
- **S/T:** pegar misconfig antes do apply.
- **A:** gate Trivy fail-closed (HIGH/CRITICAL) + testes nativos com mock provider no PR.
- **R:** vulnerabilidade barrada no PR, não em produção.

---

## Pontos fortes pra puxar
- **Kubernetes (CKA):** provisiono EKS via Terraform **e** opero com **Helm** (charts/releases) e **Kustomize** (overlays por ambiente). Ciclo completo.
- **Segurança AWS:** KMS (em repouso), TLS (em trânsito), IRSA + OIDC (least-privilege), endpoint privado + VPC endpoints (superfície), control-plane logging (auditoria).
- **Multi-cloud:** AWS + GCP — base de IaC/redes/segurança portável.

## Gaps reais (honestidade — contextualizar)
- **Observability:** "kube-prometheus-stack (Prometheus/Grafana/Alertmanager) ou CloudWatch Container Insights; RED/USE, SLO com error budget, alertas → PagerDuty. No GCP já fiz alert policies."
- **Incident response:** "runbooks versionados, on-call, severidade, postmortem blameless, MTTD/MTTR."
- **Compliance frameworks:** "meus controles (KMS, audit, IRSA, segregação de ambientes) mapeiam pra SOC 2 / PCI-DSS; usaria AWS Config/Security Hub p/ evidência contínua."
- **PowerShell:** "Meu shell é Bash; PowerShell pego rápido."

---

## Rapid-fire (fatos AWS pra soltar com confiança)
- **IRSA:** OIDC do EKS → IAM role com trust policy no SA → annotation `eks.amazonaws.com/role-arn`. Sem chave no pod.
- **KMS:** envelope encryption dos secrets do etcd; rotação de chave.
- **CI keyless:** GitHub OIDC → `sts:AssumeRoleWithWebIdentity`, role por ambiente.
- **Rede:** VPC privada multi-AZ (1a/1b), **VPC endpoints** (acesso privado a serviços AWS), nós privados, bastion.
- **State:** backend **S3** (bootstrap), isolado por ambiente.
- **Estrutura:** 2 camadas (foundation/workload) + hml/prod; remote state.
- **Reliability:** multi-AZ, managed node groups, HPA + Cluster Autoscaler/Karpenter, PDB, probes.
- **EKS upgrade:** control plane → node groups com surge/drain + PDB.
- **K8s (CKA):** Helm (templating) vs Kustomize (overlays, sem template) — sei quando usar cada um.

## Provável Q&A
- *Secrets num EKS?* → KMS envelope + IRSA + External Secrets/Secrets Manager.
- *CI autentica na AWS sem chave?* → OIDC assume-role.
- *Terraform multi-ambiente?* → 2 camadas, backend S3, env dirs.
- *Acesso de pod a S3?* → IRSA (role por SA), não node role.
- *Protege o control plane?* → endpoint privado + authorized CIDRs + logging.
- *Trade-off difícil?* → endpoint privado vs. CI público.
- *Como mentora?* → docs do "porquê" + testes como contrato + pairing.

## Perguntas pra VOCÊ fazer (sinaliza senioridade)
- "Quais frameworks de compliance (SOC 2, PCI-DSS, ISO 27001)?"
- "Como está a observability e o on-call/incident response hoje?"
- "Maior desafio de reliability/escala da plataforma?"
- "Como infra colabora com security e legal?"
- "Multi-region/DR já é realidade ou roadmap?"

## Lembretes finais
1. **Sempre** cite o **trade-off** junto da decisão (sinal de sênior).
2. Lidere por **segurança/compliance** (é uma crypto) e conecte control técnico → risco de negócio.
3. Gaps não se escondem — mostre que conhece o caminho.
4. Tenha pitch + 5 histórias fluindo em **EN** (time global).
5. Diferencie Helm × Kustomize e IRSA × node role se perguntarem.
