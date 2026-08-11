# Topologia `data` / `app` / `edge` e a escada de Infra como Produto

> **Status:** proposta de design (não implementada). Registra a evolução da topologia atual
> (`foundation` / `workload`) para uma granularidade por componente, e mapeia onde Crossplane
> e Backstage encaixam na jornada de platform-as-a-product.
>
> Contexto: ver `docs/blog-module-environment-structure.md` (Parte 2 da série), que define a
> topologia de state atual de 2 camadas × 2 ambientes.

---

## Motivação

A topologia atual separa state por **layer** (`foundation`, `workload`) × **ambiente** (`hml`, `prod`)
— 4 states. O `workload`, porém, ainda agrupa recursos com ciclos de vida bem diferentes no mesmo
state: o banco (persistente, vive por meses) e o compute stateless (deploy 10×/dia) compartilham
blast radius.

O objetivo é poder **selecionar e operar um componente isoladamente** — "subir/derrubar só o Cloud Run
em hml, sem tocar no banco nem na rede" — mantendo a regra do artigo: **separar por ciclo de vida,
não por recurso.** A unidade de state continua sendo o *componente* (3-5 recursos que nascem e morrem
juntos), nunca o recurso individual.

---

## A topologia: states e ordem

```
            CICLO DE VIDA          STATE (por ambiente)           DEPENDE DE
            ───────────            ─────────────────────          ──────────
  lento     foundation   ──────▶   <bucket>/<env>/foundation        —
  (semanas) rede
                │
                ▼
  lento     data         ──────▶   <bucket>/<env>/data           foundation
  (dias)    persistência
                │
                ▼
  rápido    app          ──────▶   <bucket>/<env>/app             foundation + data
  (deploys) compute
                │
                ▼
  médio     edge         ──────▶   <bucket>/<env>/edge            app (+ foundation)
  (releases)ingress/WAF

  APPLY  →  foundation → data → app → edge
  DESTROY ←  edge → app → data → foundation   (ordem reversa, sempre)
```

São **4 componentes × 2 ambientes = 8 states**. Cada um continua *lifecycle-sized*, não
*resource-sized*: nunca "1 state pro Cloud Run e outro pro service account dele" — eles nascem e
morrem juntos, então vivem no mesmo state (`app`).

---

## O que vive em cada componente

| Componente | Módulos / resources | Por que juntos |
|---|---|---|
| **foundation** | `vpc`, `subnet`, `vpc_access_connector`, `service_networking_connection` (PSA), `firewall` | Rede. Muda raramente, todo o resto depende. *(já existe)* |
| **data** | `cloud_sql` (instance/db/user), `secret_manager` + `secret_rotation`, `cloud_storage`, `pubsub` (topics/subs), `artifact_registry` | Estado persistente + contratos de longa vida. Sobrevive a N deploys do app. |
| **app** | `cloud_run_service` (service + job), `iam_service_account` do app, bindings de Run/Secret | Compute stateless. Faz deploy 10×/dia. **É o que se quer criar/destruir sozinho.** |
| **edge** | `https_load_balancer` (global address, backend, url_map, proxies, forwarding, SSL cert, **serverless NEG**), `cloud_armor` (security policy) | Ingress + WAF. Aponta pro Cloud Run via NEG; muda a cada release, não a cada deploy. |

> **Nota sobre `artifact_registry`:** é build-time, compartilhado e de vida longa. Fica em `data`
> por ser persistente; em escalas maiores poderia virar um componente `platform` próprio.

---

## A fiação entre states (`remote_state`)

Cada componente lê só de quem está **acima** dele — dependência explícita e direcional:

```hcl
# data/remote_state.tf — precisa da rede pro Cloud SQL privado
data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config  = { bucket = var.state_bucket, prefix = "${var.environment}/foundation" }
}
# usa: psa_connection_id, vpc_network_id

# app/remote_state.tf — precisa do connector E do banco/secret
data "terraform_remote_state" "foundation" { ... prefix = ".../foundation" }
data "terraform_remote_state" "data"       { ... prefix = ".../data" }
# usa: vpc_connector_id (foundation) + db_connection_name, secret_id (data)

# edge/remote_state.tf — precisa do Cloud Run pra montar o NEG
data "terraform_remote_state" "app" { ... prefix = ".../app" }
# usa: cloud_run_service_name, cloud_run_region
```

**Regra de ouro:** a seta só aponta pra baixo. `edge` nunca lê `app` que lê `edge` de volta —
um ciclo entre states o Terraform não detecta, e vira deadlock operacional.

---

## Integração com a pipeline (estendendo o que já existe)

O dispatch atual (`terraform-deploy.yml`, `terraform-destroy.yml`, `terraform-plan.yml`) usa
`layer: [foundation, workload, both]`. Vira:

```yaml
component:
  type: choice
  options: [foundation, data, app, edge, all]
```

A ordem fica **codificada num único lugar** (não na cabeça de quem aperta o botão):

```bash
# resolve a sequência a partir da seleção
case "$component" in
  all)  order="foundation data app edge" ;;
  *)    order="$component" ;;            # um componente só
esac
# destroy usa a mesma lista invertida: edge app data foundation
```

Resultado: selecionar `app` + `hml` no Actions sobe/derruba só o Cloud Run, com state próprio —
sem encostar no banco (`data`) nem na rede (`foundation`).

> **Ganho concreto:** destruir o `app` do hml de madrugada pra economizar custo e recriar de manhã
> com `terraform apply`. O `data` nunca é tocado; os dados sobrevivem.

---

## Infra como produto: a escada de maturidade

Tratar a infra como produto = ela tem *usuários* (os devs), *golden paths* (o jeito certo e fácil),
um *catálogo* e *SLOs*. Quatro degraus:

```
 L0  Root monolítico            "um apply faz tudo"            ← ponto de partida
       │  blast radius grande
       ▼
 L1  States por lifecycle       "self-service via PR/dispatch" ← AQUI (data/app/edge)
     + pipeline com dropdown        dev abre PR ou aperta botão no Actions
       │  ainda exige saber Terraform e a estrutura
       ▼
 L2  Catálogo + golden paths    "self-service via portal"       ← Backstage/Port
     (templates/scaffolder)         dev preenche um form, não vê Terraform
       │  ainda é apply one-shot; drift não auto-corrige
       ▼
 L3  Control plane reconciliado "self-service via API/claims"    ← Crossplane
     (composições)                  dev declara o que quer; controlador reconcilia sempre
```

Cada degrau **adiciona capacidade e custo**. A arte é parar no degrau certo pro tamanho do time.
A topologia `data/app/edge` é a consolidação do L1 — fica toda dentro do tooling atual, zero
ferramenta nova.

---

## Onde entra o Crossplane (o motor)

Crossplane troca o **modelo de provisionamento**, não só a UX.

| | Terraform (hoje) | Crossplane |
|---|---|---|
| Modelo | imperativo: `apply` one-shot | declarativo: **control loop** que reconcilia sempre |
| State | arquivo no GCS | objetos no etcd do Kubernetes |
| Drift | detectado só no próximo `plan` | **auto-corrigido** continuamente |
| Abstração | módulo `.tf` | **Composition** (XRD) — define um tipo novo |

O time de plataforma escreve uma **Composition** que empacota "Cloud Run + SA + NEG + binding de
secret" num tipo de alto nível, ex.: `CloudRunApp`. O dev cria um **claim** — um YAML curto:

```yaml
apiVersion: platform.suaempresa.io/v1
kind: CloudRunApp
metadata: { name: checkout, namespace: hml }
spec:
  image: us-docker.pkg.dev/.../checkout:abc123
  cpu: "1"
```

Um controlador roda 24/7 garantindo que a GCP bate com esse YAML. Deletou o Cloud Run no console?
O Crossplane **recria sozinho**. É o `app`/`edge` deste protótipo, mas como **API contínua** em vez
de pipeline disparada.

- **Quando vale:** API self-service de verdade + drift-correction automático, com time já em Kubernetes.
- **Quando não vale:** o caso atual — sem cluster, Terraform + pipeline entrega 90% disso com 10% da
  complexidade. Rodar e manter o control plane é trabalho operacional real.

---

## Onde entra o Backstage + workflow (a porta de entrada)

Backstage **não provisiona nada**. É o **portal do desenvolvedor**: catálogo de software + *scaffolder*
(templates com formulário). Camada de UX por cima do que já existe.

```
  Dev no Backstage          Scaffolder template            Backend (escolha sua)
  ───────────────           ───────────────────            ─────────────────────
  "criar serviço"   ──▶     form: env=[hml,prod]    ──▶    aciona UM destes:
                                  component=[app,...]         • GitHub Actions dispatch ← A PIPELINE
                                  image=...                   • PR que adiciona unit Terragrunt
                                                              • claim do Crossplane
```

Ponto-chave: **o workflow que o Backstage dispara pode ser exatamente a `terraform-deploy.yml`**.
O template faz um `workflow_dispatch` com `environment` + `component` — os inputs que já existem.
Backstage vira a "cara"; a pipeline continua sendo o motor. (Port é o equivalente SaaS — mesmo papel,
menos auto-hospedagem.)

---

## Como as peças se encaixam

```
  ┌─────────────────────────────────────────────────────────┐
  │  PORTA DE ENTRADA (UX/catálogo)    Backstage / Port      │ ← L2
  ├─────────────────────────────────────────────────────────┤
  │  ORQUESTRAÇÃO                      GitHub Actions ← ATUAL │
  │                                    (Terragrunt opcional)  │ ← L1
  ├─────────────────────────────────────────────────────────┤
  │  MOTOR DE PROVISIONAMENTO          Terraform ← ATUAL      │
  │                                    (ou Crossplane)        │ ← L3 troca aqui
  ├─────────────────────────────────────────────────────────┤
  │  CLOUD                             GCP                    │
  └─────────────────────────────────────────────────────────┘
```

- **Hoje:** as duas camadas do meio (Actions + Terraform) estão ocupadas. Sólido.
- **Próximo passo:** a topologia `data/app/edge` — dentro do tooling atual, zero ferramenta nova.
- **Backstage:** adicionar a porta de entrada por cima, quando devs sem contexto de Terraform
  precisarem se servir sozinhos.
- **Crossplane:** trocar o motor por reconciliação contínua, quando drift-correction automático e
  API declarativa justificarem rodar um control plane.

A armadilha clássica é pular pro L3 (Crossplane) sem dor que justifique — vira-se mantenedor de
control plane antes de ter usuários. A ordem certa: **arrumar a topologia de state primeiro (L1),
depois a UX (L2), e só então o motor (L3) se a escala pedir.**

---

## Próximos passos de implementação (quando for adotar)

1. Criar os roots `data/`, `app/`, `edge/` com `version.tf` (partial backend), `provider.tf`,
   `remote_state.tf` e `environments/{hml,prod}/{backend.hcl,terraform.tfvars}`.
2. Mover os módulos do `workload` atual para o componente correspondente (`data`/`app`/`edge`).
3. Publicar os outputs de contrato em cada componente (`data`: `db_connection_name`, `secret_id`;
   `app`: `cloud_run_service_name`, `cloud_run_region`).
4. Estender o dropdown `component` nas três workflows e codificar a ordem apply/destroy num único passo.
5. Migrar o state existente (`terraform state mv` / re-import) por ambiente, começando pelo `hml`.
