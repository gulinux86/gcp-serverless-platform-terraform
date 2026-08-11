---
title: "Topologia de state no Terraform: fronteiras de módulos e ambientes"
subtitle: "Refatorando uma stack serverless na GCP de um root único para camadas independentes e state por ambiente — o que foi construído, por que essa estrutura e os trade-offs."
tags: [Terraform, GCP, InfrastructureAsCode, PlatformEngineering, DevOps]
---

# Topologia de state no Terraform: fronteiras de módulos e ambientes

> **Parte 2 de 2.** A Parte 1 cobre as pipelines de entrega que rodam em cima desta estrutura: [Entregando infraestrutura serverless na GCP com Terraform]([link da Parte 1]).

Todo `terraform apply` opera sobre um único arquivo de state. Esse arquivo é a unidade atômica de blast radius, de lock e de tempo de plan. A estrutura de módulos é organização; **a topologia de state é arquitetura.** Foi assim que uma plataforma serverless na GCP foi refatorada de um root único para **duas camadas independentes em dois ambientes** — uma grade 2×2 de arquivos de state — e o porquê.

---

## O que foi construído

Duas camadas, separadas por ciclo de vida. Cada uma é um root independente do Terraform, com seu próprio backend e state.

| Camada | Módulo | Resources principais |
|---|---|---|
| **foundation** (ciclo lento) | `vpc` | `google_compute_network`, `google_compute_subnetwork`, `google_vpc_access_connector` (Serverless VPC Access), `google_service_networking_connection` (PSA / Cloud SQL privado) |
| | `cloud_firewall` | `google_compute_firewall` |
| **workload** (ciclo rápido) | `cloud_run_service` | `google_cloud_run_v2_service`, `google_cloud_run_v2_job`, IAM members do Run |
| | `cloud_sql` | `google_sql_database_instance` (IP privado), `google_sql_database`, `google_sql_user` |
| | `https_load_balancer` | `google_compute_global_address`, `backend_service`, `url_map`, `target_https_proxy` + `target_http_proxy`, `global_forwarding_rule`, `managed_ssl_certificate`, `region_network_endpoint_group` serverless |
| | `cloud_armor` | `google_compute_security_policy` (WAF / rate limiting no LB) |
| | `artifact_registry` | `google_artifact_registry_repository` (imagens de container) |
| | `secret_manager` + `secret_rotation` | `google_secret_manager_secret`/`version`, `logging_project_sink`, `pubsub_topic`/`subscription`, `monitoring_alert_policy` (sinal de rotação) |
| | `pubsub` | `google_pubsub_topic`/`subscription` (mensageria da aplicação) |
| | `cloud_storage` | `google_storage_bucket` + IAM |
| | `iam_service_account` | `google_service_account` + bindings (menor privilégio por serviço) |

Um root separado, `bootstrap`, provisiona a junção de CI sem chaves — `google_iam_workload_identity_pool` + `provider` para OIDC do GitHub Actions — de modo que nenhuma chave de service account fica no repositório.

---

## Por que essa estrutura

**Separar por ciclo de vida, não por diagrama.** A rede muda raramente e é compartilhada; o compute da aplicação muda a cada deploy. Colocar os dois no mesmo state significa que uma mudança de uma linha no Cloud Run re-planeja a VPC, o Cloud SQL e o load balancer, segura o lock da stack inteira e torna o `destroy` tudo-ou-nada. Separá-los faz o **blast radius corresponder à mudança**.

**Dois eixos ortogonais:**

```
                  ┌──────────────────┬──────────────────┐
                  │      hml         │       prod       │
   ┌──────────────┼──────────────────┼──────────────────┤
   │ foundation   │ <bucket>/hml/    │ <bucket>/prod/   │
   │ (rede)       │   foundation     │   foundation     │
   ├──────────────┼──────────────────┼──────────────────┤
   │ workload     │ <bucket>/hml/    │ <bucket>/prod/   │
   │ (app + dados)│   workload       │   workload       │
   └──────────────┴──────────────────┴──────────────────┘
        eixo de camada ──────────────▶  eixo de ambiente
```

- **Eixo de camada** — *o que muda junto vs. o que muda de forma independente.*
- **Eixo de ambiente** — *o mesmo código contra cópias isoladas do mundo.*

Misturar os dois é um erro comum; cada um é tratado com um mecanismo diferente.

---

## Dependência entre camadas: remote state, não um root

Sem orquestrador, o `workload` descobre os IDs de VPC/connector lendo o state do `foundation`:

```hcl
# workload/remote_state.tf
data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "${var.environment}/foundation" }
}

locals {
  vpc_network_id   = data.terraform_remote_state.foundation.outputs.vpc_network_id
  vpc_connector_id = data.terraform_remote_state.foundation.outputs.vpc_connector_id
  vpc_peering_id   = data.terraform_remote_state.foundation.outputs.psa_connection_id
}
```

Escolhido em vez de um root compartilhado (acoplamento forte) e em vez de redescoberta por data source (re-consulta a API a cada plan, exige IAM de leitura). O remote state torna a dependência **explícita, direcional e gratuita no plan**.

**Consequência sênior:** o bloco `outputs` do `foundation` agora é uma **API pública**. Renomear `vpc_connector_id` quebra o `workload` no plan, em outro state. O acoplamento não desapareceu — saiu do grafo de módulos e virou um contrato de outputs versionado e uma regra de ordenação que a pipeline precisa garantir (aplicar o `foundation` primeiro, inverter no destroy).

---

## Ambientes: diretórios + partial backends (não workspaces)

Cada camada carrega **configuração por ambiente, não código**:

```
foundation/environments/
  hml/   { backend.hcl, terraform.tfvars }
  prod/  { backend.hcl, terraform.tfvars }
```

```hcl
# version.tf — partial backend, completado no init
terraform { backend "gcs" {} }
```
```bash
terraform -chdir=foundation init -backend-config=environments/hml/backend.hcl
```

**Não workspaces:** trocam de state por um ponteiro oculto da CLI (invisível "para qual ambiente estou aplicando?") e forçam todos os ambientes a compartilhar uma configuração. **Não Terragrunt (ainda):** DRY entre ambientes também os acopla; para 2 ambientes × 2 camadas, a duplicação são alguns arquivos `backend.hcl`/`tfvars` — legíveis e editáveis de forma independente. O Terragrunt se justifica quando o produto ambiente × camada torna isso doloroso.

**Divisão em três** que torna os mesmos módulos promovíveis sem alteração:

- **Código** (`.tf`, `modules/`) — agnóstico de ambiente; nunca nomeia um projeto ou segredo.
- **Configuração** (`backend.hcl`, `tfvars`) — versionada, sem segredo: prefixo, região, bucket de state, label do ambiente.
- **Segredos** (`project_id`, senha do banco, chaves) — injetados em runtime via `TF_VAR_*` pela CI; nunca versionados.

> Ressalva: o `.gitignore` padrão ignora `*.tfvars`. Quando os segredos vivem em `TF_VAR_*`, os tfvars são *configuração* e precisam ser versionados — adicione uma exceção específica ou os runners da CI não os encontrarão.

A promoção `hml` → `prod` é o mesmo código com um backend + var-file diferentes. O `prod` difere apenas em configuração e governança (protected environment, reviewer obrigatório).

---

## Trade-offs

| Decisão | Vantagem | Custo |
|---|---|---|
| Camadas independentes vs. um root | Blast radius por camada; deploy do `workload` sem tocar na rede | Ordenação vira contrato operacional, não garantia do grafo |
| Handshake por remote state vs. inputs de root / data sources | Dependência explícita, direcional e gratuita no plan | Outputs viram API pública; consistência eventual; produtor precisa existir antes |
| Diretórios vs. workspaces | Ambiente explícito; ambientes podem divergir | Duplicação de config por ambiente |
| Diretórios vs. Terragrunt | Legível, editável de forma independente | Duplicação cresce com ambiente × camada |
| Divisão config/segredo | Mesmo código promove sem alteração; sem segredos no repo | `.gitignore` e plumbing de CI exigem cuidado |
| Partial backends | Uma base de código, vários states | Fácil dar init no ambiente errado se scriptar sem cuidado |

---

## Quando esse design está errado

- **Sistemas pequenos e de vida curta** — um root único é menos para raciocinar.
- **Camadas que de fato compartilham o ciclo de vida** — separar só adiciona um contrato de ordenação sem ganho.
- **Muitos ambientes × muitas camadas** — diretórios geridos à mão viram o problema de duplicação que o Terragrunt resolve.
- **Times que tratam os outputs entre camadas de forma displicente** — sem disciplina nos outputs, você troca um erro em tempo de compilação por uma surpresa em runtime, entre states.

Duas-camadas-por-dois-ambientes é um ponto ótimo, não uma lei universal. A refatoração não deixou o sistema menor — fez o **blast radius corresponder à mudança**.

---

## O que se ganha

Consolidando, o que essa estrutura entrega na prática:

- **Blast radius isolado.** Uma mudança no `workload` não toca — nem re-planeja — VPC, Cloud SQL ou load balancer. O raio de impacto de cada `apply` fica do tamanho da camada, não da plataforma inteira.
- **Plan e apply mais rápidos.** Cada state guarda só os resources da sua camada, então o `plan` lê e diffa um grafo menor. *(Medido: foundation `<X>s` → workload `<Y>s`, contra `<Z>s` do root único.)*
- **Deploy independente por camada.** Dá para entregar a aplicação dezenas de vezes ao dia sem encostar na rede, que permanece estável por semanas.
- **Lock por camada.** O `state lock` é segurado por camada, não pela stack inteira — sem contenção entre um deploy de app e uma mudança de rede que rodam em paralelo na CI.
- **Promoção sem branch nem merge.** `hml` → `prod` é o mesmo código com outro backend e var-file; a diferença é configuração e governança, não código. Acaba o "funciona no hml mas não no prod" por divergência de código.
- **Destroy cirúrgico.** Dá para destruir e recriar uma camada (ex.: o `workload` inteiro do hml para economizar) sem arrastar a rede junto — em vez de um `destroy` tudo-ou-nada.
- **Sem segredos no repositório.** A divisão código/config/segredo mantém os `tfvars` versionáveis e empurra todo dado sensível para `TF_VAR_*` na CI.

O custo desses ganhos está na tabela de trade-offs acima — principalmente a ordenação que vira contrato operacional e os outputs que viram API pública. Para esta escala, a troca compensa.

---

> **Parte 1:** auth sem chaves, plan no PR, apply com gate, destroy confirmado → [Entregando infraestrutura serverless na GCP com Terraform]([link da Parte 1]).

---

*Parte 2 de 2. Construído com Terraform, Cloud Run e GitHub Actions no Google Cloud.*
