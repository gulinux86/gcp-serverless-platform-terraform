# Workload layer — HML. project_id, db_password, api_secret_key via TF_VAR_* (secrets).
name         = "app-hml"
region       = "us-central1"
environment  = "hml"
state_bucket = "serverless-hml"

# --- Workload Identity ----------------------------------------------------------
# "<namespace>/<ksa>". The microservices ApplicationSet in the GitOps repo names
# each Application "<svc>-<env>", deploys it to namespace "<svc>-<env>", and the
# common chart names the KSA after the release — hence "<svc>-<env>/<svc>-<env>".
# Change these together with the chart, or the pods get no Google credentials.
backend_ksas          = ["backend-hml/backend-hml"]
frontend_ksas         = ["frontend-hml/frontend-hml"]
external_secrets_ksas = ["external-secrets/external-secrets"]

# --- Argo CD ----------------------------------------------------------------------
# Pinned, not defaulted: an unpinned chart means a rebuild can install a different
# Argo CD than the one that was reviewed. Same pin as eks-terraform.
argocd_chart_version = "10.4.0"

# One repository holds both platform components and applications; the two
# AppProjects still split their privileges.
platform_repo_url      = "https://github.com/gulinux86/gke-gitops-platform-apps"
platform_repo_revision = "main"
platform_repo_path     = "bootstrap/apps"
apps_repo_url          = "https://github.com/gulinux86/gke-gitops-platform-apps"

# Prefix globs: a new environment of an existing service needs no Terraform
# change, and system namespaces (kube-system, argocd, gke-gateway-system,
# external-secrets) stay out of reach because they do not match.
apps_namespaces = ["frontend-*", "backend-*"]

# Chart repositories count as sources: Argo CD checks an Application's chart
# source against this list, so a missing entry fails the sync with "repo is not
# permitted" rather than with anything that names the chart.
#
# github.com/kubernetes-sigs/gateway-api is left out on purpose: with
# gateway_api_config enabled, GKE installs and upgrades the Gateway API CRDs
# itself, and a second owner reconciling them from Git would fight it.
platform_source_repos = [
  "https://github.com/gulinux86/gke-gitops-platform-apps",
  "https://argoproj.github.io/argo-helm",
  "https://charts.jetstack.io",
  "https://charts.external-secrets.io",
  "https://prometheus-community.github.io/helm-charts",
]

apps_source_repos = ["https://github.com/gulinux86/gke-gitops-platform-apps"]
