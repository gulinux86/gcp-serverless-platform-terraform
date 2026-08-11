# LinkedIn posts (short versions)

> Paste the relevant block into LinkedIn. Replace `[Medium link]` with your published URL.
> LinkedIn rewards short lines and white space — the formatting below is intentional.

---

## Post 1 — CI/CD pipelines (links to Article 1)

Most "Terraform CI/CD" tutorials stop at a happy-path `plan` and `apply`.

Real delivery is the part they skip: authenticating without long-lived keys, keeping prod one approval away (not one click), giving reviewers a readable diff, and tearing everything down without the cloud fighting you.

I wrote up the delivery model I built for a serverless GCP stack (Cloud Run + Cloud SQL + global LB) — 5 GitHub Actions pipelines, fully keyless via Workload Identity Federation.

The decisions that actually mattered:

🔑 Keyless > convenient — WIF is more setup than a JSON key, and the right default every time.

🚦 Gates fail closed, feedback fails open — the apply gate blocks on real failures; the plan check skips gracefully when infra isn't wired up yet, instead of going red on every PR.

💸 The cheap primitive can carry a hidden tax — Direct VPC Egress was cheaper to run and far more expensive to *destroy* (stranded subnet IPs). Switching to a VPC Access Connector deleted an entire class of teardown hacks.

🐢 Manual deploys are a feature — for infra, friction beats "push to delete a database."

The article is honest about the trade-offs, including the ones I got wrong first.

👉 [Medium link]

What's your take — do you gate prod with manual approval, or trust the pipeline?

#Terraform #GCP #DevOps #CICD #PlatformEngineering

---

## Post 2 — State topology / module & environment structure (links to Article 2)

Here's the Terraform question almost nobody asks out loud:

What is your unit of blast radius?

Every `terraform apply` operates on exactly one state file. That file is your atomic unit of risk, locking, and plan time — i.e. "what a bad apply can take down with it."

Module structure is mostly aesthetics. State topology is architecture.

I refactored a GCP serverless platform from a single root into two independent layers across two environments — a 2×2 grid of state files — and wrote up the reasoning at a senior level:

🧱 Separate along lifecycle, not diagrams — networking and compute split because they *change* at different speeds, not because they look like two boxes.

🔌 Cross-layer outputs are an API — reading another layer's remote state turns implicit module coupling into a versioned interface. That's a feature *and* a responsibility.

📁 Directories + partial backends > workspaces — they put the environment in the command, not in hidden CLI state, and let environments diverge.

🧯 Resist premature DRY — readable per-env duplication beats a Terragrunt wrapper nobody understands… until the scale flips the math.

It also covers when this design is the *wrong* one — because knowing that is the actual senior skill.

👉 [Medium link]

How do you isolate environments — directories, workspaces, or Terragrunt?

#Terraform #InfrastructureAsCode #GCP #PlatformEngineering #DevOps

---

## Optional: framing as a 2-part series

If you publish both, add a line at the top of each:

- Post 1: "Part 1 of 2 on building a keyless, two-layer Terraform delivery model on GCP."
- Post 2: "Part 2 of 2 — the state topology underneath the pipelines."
