---
title: "Entregando infraestrutura serverless na GCP com Terraform: cinco pipelines e os trade-offs por trás delas"
subtitle: "Um modelo de entrega keyless, em duas camadas, com GitHub Actions para Cloud Run — e as decisões de engenharia (e os erros) que o moldaram."
tags: [Terraform, GCP, GitHubActions, DevOps, Serverless, CICD]
---

# Entregando infraestrutura serverless na GCP com Terraform: cinco pipelines e os trade-offs por trás delas

> **Parte 1 de 2** sobre construir um modelo de entrega keyless e em duas camadas com Terraform na GCP. A Parte 2 mergulha por baixo do capô: [Topologia de state no Terraform: desenhando fronteiras de módulos e ambientes que escalam]([link da Parte 2]).

A maioria dos artigos de "Terraform CI/CD" mostra um `plan` e um `apply` no caminho feliz e encerra o assunto. Entrega de verdade é mais bagunçada: como autenticar sem chaves de longa duração, impedir que `prod` esteja a um clique de distância, dar ao revisor um diff legível, e destruir tudo sem a nuvem brigar com você na saída?

Este é um passo a passo de um pipeline de entrega com cara de produção para uma stack serverless na GCP (Cloud Run + Cloud SQL + um load balancer HTTPS global, tudo provisionado com Terraform). Vou pipeline por pipeline — mas o valor real está nos **trade-offs**: as decisões em que não havia uma resposta obviamente certa, e algumas em que eu errei antes de acertar.

---

## O formato do sistema

A plataforma são duas camadas Terraform, cada uma um **root module independente com seu próprio remote state**:

```
foundation/   →  VPC, subnets, Serverless VPC Access Connector, PSA peering, firewall
                 └── state GCS: gs://<bucket>/<env>/foundation/
workload/     →  Cloud Run, Cloud SQL, Load Balancer, Cloud Armor, secrets, IAM
                 └── state GCS: gs://<bucket>/<env>/workload/
                 lê os outputs do foundation via terraform_remote_state
```

Em cima disso, cinco workflows do GitHub Actions:

| Workflow | Gatilho | Função |
|---|---|---|
| `terraform-test` | PR | Testes de módulo (providers mockados, sem nuvem) |
| `security-scan` | PR | Scan IaC com Trivy, falha em HIGH/CRITICAL |
| `terraform-plan` | PR + manual | Plan por camada, postado como comentário na PR |
| `terraform-deploy` | manual | Apply gated de um plan salvo |
| `terraform-destroy` | manual | Teardown confirmado, em ordem reversa |

Tudo que toca a GCP autentica via **Workload Identity Federation** — não há nenhuma chave JSON de service account no repositório nem no GitHub.

---

## Trade-off #1: duas camadas independentes vs. um root único

A decisão mais consequente foi dividir a stack em duas raízes em vez de uma.

**Um root** é mais simples: um único `terraform apply` constrói o mundo, e o grafo de módulos impõe a ordenação automaticamente. Mas qualquer mudança — até um ajuste de uma linha numa env var do Cloud Run — replaneja a VPC inteira, e um `destroy` é tudo-ou-nada.

**Duas raízes** trocam essa simplicidade por um blast radius menor. O `workload` lê os outputs do `foundation` a partir do seu remote state, em vez de recebê-los como inputs:

```hcl
# workload/remote_state.tf
data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "${var.environment}/foundation" }
}

# workload/main.tf
locals {
  vpc_network_id   = data.terraform_remote_state.foundation.outputs.vpc_network_id
  vpc_connector_id = data.terraform_remote_state.foundation.outputs.vpc_connector_id
}
```

| | Um root | Duas raízes |
|---|---|---|
| Deploy do dia a dia | Replaneja tudo | Aplica só o `workload` |
| Blast radius | Stack inteira | Por camada |
| Ordenação | Implícita (grafo) | Explícita (pipeline + remote state) |
| Carga cognitiva | Menor | Maior |

O custo de duas raízes é que "aplicar `foundation` antes do `workload`" deixa de ser garantido pelo Terraform — vira um contrato que a **pipeline** precisa honrar. Esse contrato aparece em tudo abaixo: deploy aplica `foundation → workload`, destroy inverte, e o plan se recusa a planejar o `workload` se o `foundation` ainda não foi aplicado.

---

## Trade-off #2: auth keyless (Workload Identity Federation)

O erro clássico é jogar uma chave JSON de service account num secret do GitHub. Funciona, nunca expira, e é uma dívida pra sempre.

Workload Identity Federation (WIF) permite trocar o token OIDC do GitHub por credenciais GCP de curta duração — sem chave estática. O bootstrap (rodado uma vez, por um humano, com credenciais elevadas) cria um pool, um provider restrito a *exatamente um repositório*, e uma service account de deploy:

```hcl
resource "google_iam_workload_identity_pool_provider" "github" {
  # ...
  attribute_condition = "assertion.repository == '${var.github_repo}'"
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
```

O trade-off é a **complexidade de setup**: WIF tem mais partes móveis que uma chave (pool, provider, attribute mapping, uma binding de impersonation), e é o tipo de coisa que você configura uma vez e esquece como funciona. Mas remove uma classe inteira de incidentes de vazamento de credencial, e é por ambiente, então um provider de `hml` comprometido jamais consegue emitir tokens de `prod`. Esse é um trade que vale a pena fazer sempre.

---

## As pipelines, e por que cada uma tem o formato que tem

### `terraform-test` — feedback rápido e sem credencial

Os testes de módulo usam o framework de teste nativo do Terraform com **providers mockados** (`mock_provider` + `command = plan`). Sem credencial GCP, sem infra real, roda em toda PR — inclusive de forks:

```hcl
mock_provider "google" {}

run "no_vpc_access_without_connector" {
  command = plan
  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].vpc_access) == 0
    error_message = "Nenhum bloco vpc_access deve ser renderizado quando não há connector."
  }
}
```

Esses testes pegam os assassinos silenciosos: um ternário quebrado em `count`/`for_each` que produz *zero* recursos sem dar erro. O revisor não vê isso num diff; um teste vê.

> **Trade-off:** testes mockados validam *estrutura e lógica*, não comportamento real da nuvem. Eles nunca vão pegar um erro de quota ou um gap de IAM. São um primeiro gate rápido, não um substituto pra um plan real.

### `security-scan` — um gate Trivy que falha fechado

O Trivy roda em modo `config` sobre o Terraform, sobe SARIF pra aba Security, e **falha a PR em HIGH/CRITICAL**. Exceções vivem num `.trivyignore` versionado, cada uma com justificativa escrita.

A primeira execução já provou o valor: `AVD-GCP-0015 — instância de banco não exige TLS`. Esse não é um finding pra suprimir; é um finding pra corrigir:

```hcl
ip_configuration {
  ipv4_enabled = false
  ssl_mode     = "ENCRYPTED_ONLY"   # exige TLS em trânsito
}
```

> **Trade-off:** um gate que falha fechado ocasionalmente bloqueia uma PR legítima por uma regra discutível. A política de `.trivyignore`-com-justificativa mantém o gate honesto sem deixá-lo virar carimbo.

### `terraform-plan` — feedback read-only que não trava por falta de infra

O plan posta o diff como comentário na PR, pra que mudanças sejam revisadas antes de aplicadas. O problema de design interessante: um plan real precisa de auth na nuvem e de um backend populado, mas você não quer que a PR fique vermelha só porque o WIF ainda não foi configurado, ou porque alguém abriu uma PR de docs.

Então o workflow de plan **sempre** roda `fmt` e um `validate` sem credencial, e só tenta o plan real quando o WIF está configurado — caso contrário, pula com um comentário explicativo em vez de falhar:

```bash
if [ -z "$WIF_PROVIDER" ]; then
  terraform -chdir="$LAYER" init -backend=false
  terraform -chdir="$LAYER" validate     # ainda é feedback real
  echo "Plan pulado — WIF não configurado para ${ENV}."
  exit 0
fi
```

Ele também protege a dependência entre camadas: antes de planejar o `workload`, checa se o state do `foundation` realmente tem outputs, e pula com "aplique o foundation primeiro" em vez de despejar um erro cru de `terraform_remote_state`.

> **Trade-off:** um check "pulado" é um check verde. Você troca gating estrito por fluidez de desenvolvimento — aceitável pro plan (que é consultivo), inaceitável pro gate de apply.

### `terraform-deploy` — manual, gated, e só com plan salvo

Nada aplica no merge. Deploy é um dispatch manual onde você escolhe o ambiente e a camada (`foundation`, `workload` ou `both`). O caso do dia a dia é um apply só do `workload`, que nunca toca a rede.

Dois gates rodam antes de qualquer apply — os testes de módulo e o scan Trivy — e `prod` está atrelado a um GitHub Environment com revisor obrigatório, então uma execução de prod *pausa pra aprovação*. O apply sempre usa um plan salvo (`plan -out` e depois `apply tfplan`), nunca um re-plan na hora de aplicar.

```yaml
on:
  workflow_dispatch:
    inputs:
      environment: { type: choice, options: [hml, prod] }
      layer:       { type: choice, options: [foundation, workload, both] }
```

> **Trade-off:** deploys manuais são mais lentos que push-to-deploy. Para infraestrutura — onde um apply ruim pode deletar um banco de dados — esse atrito é feature, não bug.

### `terraform-destroy` — confirmado e em ordem reversa

Destroy é o botão mais perigoso do repo, então carrega as maiores travas: uma confirmação digitada que tem que bater com o nome do ambiente, o mesmo gate de revisor pra `prod`, e ordem reversa (`workload` antes de `foundation`). Compartilha um grupo de concorrência com o deploy, então um teardown jamais sobrepõe um apply do mesmo ambiente.

```bash
if [ "$confirm" != "$ENVIRONMENT" ]; then
  echo "Confirmação não bate com o ambiente. Abortando."; exit 1
fi
```

---

## Os trade-offs que realmente me morderam

As decisões acima foram deliberadas. Estas foram aprendidas no susto.

### Direct VPC Egress vs. VPC Access Connector

O Cloud Run originalmente alcançava a VPC via **Direct VPC Egress** (`vpc_access.network_interfaces.subnetwork`). É mais barato e tem mais throughput — e reserva endereços IP silenciosamente *dentro da sua subnet de aplicação*. A GCP não libera essas reservas rapidamente no teardown; ela as segura por até ~120 minutos, o que significa que o `terraform destroy` falha tentando deletar uma subnet que está "ainda em uso".

O código original mascarava isso com uma pequena floresta de guards `time_sleep` e um handshake de sinal de decomissionamento entre camadas. Funcionava, mas era frágil e lento.

Mudar para um **Serverless VPC Access Connector** removeu a causa raiz. O connector é um recurso gerenciado num `/28` dedicado, então deletar o Cloud Run não deixa nada preso na subnet de app — e todos aqueles guards de teardown simplesmente desapareceram.

| | Direct VPC Egress | VPC Access Connector |
|---|---|---|
| Custo | Menor | Instâncias sempre ativas |
| Throughput | Maior | Limitado |
| Teardown | Esperas de IP, frágil | Delete limpo e gerenciado |

> **Lição:** a primitiva de rede mais barata carregava um imposto operacional escondido na hora do *destroy*. Para uma stack que é criada e destruída com frequência, um teardown previsível valeu mais que throughput de pico.

### PSA vs. PSC para o Cloud SQL

A espera de teardown que sobra é o **Private Service Access (PSA)** — o peering de VPC que dá ao Cloud SQL um IP privado. O PSA segura um lock interno por vários minutos após a deleção da subnet; a config absorve isso com `deletion_policy = "ABANDON"` e um buffer de 10 minutos. O **Private Service Connect (PSC)** evita o peering por completo e destrói limpo — mas adiciona um endpoint por instância e DNS pra gerenciar. Para uma VPC única com um banco, a simplicidade do PSA ainda vence; em escala multi-VPC, o PSC venceria.

### O `terraform test` nativo é sensível à versão

Um teste de módulo passava localmente e falhava no CI. Mesmo código, versão diferente do Terraform. O culpado era indexar um bloco `set` dentro da condição `if` de um `for`:

```hcl
# falha nas regras que não têm rate_limit_options
if rule.action == "throttle" && rule.rate_limit_options[0]...

# robusto entre versões
if try(rule.rate_limit_options[0].rate_limit_threshold[0].count, null) == 50
```

> **Lição:** fixe o Terraform local na versão do CI. "Funciona na minha máquina" é um modo de falha real no `terraform test`, onde a semântica de avaliação mudou entre releases menores.

### O `.gitignore` que comeu minhas variáveis

O `.gitignore` padrão do Terraform ignora `*.tfvars` — sensato, já que tfvars muitas vezes guardam secrets. Mas meus tfvars por ambiente guardavam apenas config *não-secreta* (prefixo de nome, região). Eles nunca foram commitados, silenciosamente, e o `terraform-deploy` morria com "variables file does not exist" só depois de um `init` limpo. A correção foi uma negação com escopo:

```gitignore
*.tfvars
!**/environments/*/terraform.tfvars   # config não-secreta; secrets via TF_VAR_*
```

> **Lição:** "secrets via `TF_VAR_*`, config em tfvars versionados" é uma divisão limpa — mas o `.gitignore` boilerplate assume que todo tfvars é secret. Audite-o.

### `project_id` é um secret?

Um project ID da GCP não é uma credencial, mas para um repo de portfólio público eu não queria commitá-lo. A resposta pragmática: injetá-lo como `TF_VAR_project_id` a partir de um secret do GitHub, manter só valores não-identificadores nos tfvars, e dar ao bucket de state um nome fixo (`serverless-hml`) em vez de um derivado do project ID.

> **Ressalva honesta:** tratar `project_id` como secret o mantém fora do repo e fora dos logs de step — mas o output do `terraform plan` (postado como comentário na PR) ainda o contém nos paths dos recursos, e o GitHub não mascara secrets em comentários criados via API. "Secret" aqui significa "não-commitado", não "nunca visível".

### `editor` vs. least privilege

A SA de deploy carrega `roles/editor` mais `iam.securityAdmin`. É grosseiro — o oposto do least-privilege por recurso que as identidades *de aplicação* usam. A justificativa é honesta: `editor` + `securityAdmin` cobre as duas coisas que normalmente quebram applies serverless — `iam.serviceAccounts.actAs` (Cloud Run rodando *como* uma service account) e `*.setIamPolicy` (as dezenas de bindings finas) — sem um whack-a-mole de permissões negadas. Apertar isso para uma lista de roles curada é um follow-up conhecido e adiado.

> **Lição:** least privilege para identidades de *workload* é inegociável. Para o *deployer*, há um trade-off real de velocidade vs. privilégio, e ser explícito sobre a dívida é melhor que fingir que ela não existe.

---

## Conclusões

- **Empurre o contrato de dependência para a pipeline.** Duas camadas independentes compram um blast radius menor, mas só se deploy/destroy/plan honrarem a ordenação que o grafo de módulos garantia antes.
- **Keyless vence o conveniente.** Workload Identity Federation dá mais trabalho que uma chave JSON, e é o default certo toda vez.
- **Gates devem falhar fechados; feedback deve falhar aberto.** O gate de apply bloqueia em falhas reais; o check de plan pula com elegância quando a infra ainda não está montada.
- **A primitiva barata pode cobrar um imposto escondido.** Direct VPC Egress era mais barato de rodar e muito mais caro de destruir.
- **Nomeie suas dívidas.** A role `editor` e o buffer de teardown do PSA são trade-offs deliberados e documentados — não acidentes.

A stack completa — duas camadas, cinco pipelines, auth keyless e um modelo de rede baseado em connector — faz deploy do `hml` de ponta a ponta e destrói limpo na primeira passada. A parte interessante nunca foi o YAML. Foi cada lugar onde tive que escolher o que otimizar.

**A seguir:** as pipelines se apoiam numa topologia de state deliberada — duas camadas independentes em dois ambientes. A Parte 2 destrincha esse design, as alternativas que rejeitei (workspaces, Terragrunt), e quando é a escolha *errada* → [Topologia de state no Terraform: desenhando fronteiras de módulos e ambientes que escalam]([link da Parte 2]).

---

*Parte 1 de 2. Construído com Terraform, Cloud Run e GitHub Actions no Google Cloud. Feedback e histórias de guerra são bem-vindos.*
