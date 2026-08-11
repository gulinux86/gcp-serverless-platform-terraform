# Posts do LinkedIn (versões curtas, PT)

> Cole o bloco relevante no LinkedIn. Troque `[link do Medium]` pela URL publicada.
> O LinkedIn premia linhas curtas e espaço em branco — a formatação abaixo é proposital.

---

## Post 1 — Pipelines de CI/CD (aponta para o Artigo 1)

A maioria dos tutoriais de "Terraform CI/CD" para num `plan` e `apply` no caminho feliz.

Entrega de verdade é a parte que eles pulam: autenticar sem chaves de longa duração, manter prod a uma aprovação de distância (não a um clique), dar ao revisor um diff legível, e destruir tudo sem a nuvem brigar com você.

Documentei o modelo de entrega que construí para uma stack serverless na GCP (Cloud Run + Cloud SQL + LB global) — 5 pipelines no GitHub Actions, totalmente keyless via Workload Identity Federation.

As decisões que realmente importaram:

🔑 Keyless > conveniente — WIF dá mais trabalho que uma chave JSON, e é o default certo toda vez.

🚦 Gates falham fechados, feedback falha aberto — o gate de apply bloqueia em falhas reais; o check de plan pula com elegância quando a infra ainda não está montada, em vez de ficar vermelho em toda PR.

💸 A primitiva barata pode cobrar um imposto escondido — Direct VPC Egress era mais barato de rodar e muito mais caro de *destruir* (IPs presos na subnet). Trocar pelo VPC Access Connector apagou uma classe inteira de gambiarras de teardown.

🐢 Deploys manuais são feature — para infra, atrito vence "push pra deletar um banco".

O artigo é honesto sobre os trade-offs, inclusive os que eu errei primeiro.

👉 [link do Medium]

E você — gateia prod com aprovação manual, ou confia na pipeline?

#Terraform #GCP #DevOps #CICD #PlatformEngineering

---

## Post 2 — Topologia de state / estrutura de módulos e ambientes (aponta para o Artigo 2)

Eis a pergunta de Terraform que quase ninguém faz em voz alta:

Qual é a sua unidade de blast radius?

Todo `terraform apply` opera em exatamente um state file. Esse arquivo é a sua unidade atômica de risco, lock e tempo de plan — ou seja, "o que um apply ruim pode derrubar junto".

A estrutura de módulos é, em boa parte, estética. A topologia de state é arquitetura.

Refatorei uma plataforma serverless na GCP de um root único para duas camadas independentes em dois ambientes — uma grade 2×2 de state files — e documentei o raciocínio em nível sênior:

🧱 Separe por ciclo de vida, não por diagrama — rede e compute se dividem porque *mudam* em velocidades diferentes, não porque parecem duas caixas.

🔌 Outputs entre camadas são uma API — ler o remote state de outra camada transforma acoplamento implícito de módulo numa interface versionada. Isso é feature *e* responsabilidade.

📁 Diretórios + partial backends > workspaces — eles colocam o ambiente no comando, não num estado escondido da CLI, e deixam os ambientes divergirem.

🧯 Resista ao DRY prematuro — duplicação legível por ambiente vence um wrapper de Terragrunt que ninguém entende… até a escala virar a conta.

O artigo também cobre quando esse design é o *errado* — porque saber isso é a real habilidade sênior.

👉 [link do Medium]

Como você isola ambientes — diretórios, workspaces ou Terragrunt?

#Terraform #InfrastructureAsCode #GCP #PlatformEngineering #DevOps

---

## Opcional: enquadrar como série de 2 partes

Se publicar os dois, adicione uma linha no topo de cada:

- Post 1: "Parte 1 de 2 sobre construir um modelo de entrega keyless e em duas camadas com Terraform na GCP."
- Post 2: "Parte 2 de 2 — a topologia de state por baixo das pipelines."
