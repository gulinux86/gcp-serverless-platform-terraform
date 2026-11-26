provider "google" {
  project = var.project_id
}

locals {
  # State bucket per environment (no project id in the name): serverless-hml / serverless-prod.
  state_bucket = "serverless-${var.environment}"
}

# ============================================
# Project APIs
# ============================================

# Enabled here, with owner credentials, rather than by the layers: enabling an
# API needs serviceusage.services.enable, which the CI identities do not hold.
resource "google_project_service" "this" {
  for_each = toset(var.project_services)

  service = each.value

  # Never disable an API on destroy: it would break every other user of the
  # project and can take resources in other states down with it.
  disable_on_destroy = false
}

# ============================================
# Workload Identity Federation — keyless CI auth
# ============================================

# A pool per environment. Keeping pools separate means a compromised hml provider
# can never mint tokens usable against prod.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-${var.environment}"
  display_name              = "GitHub Actions (${var.environment})"
  description               = "WIF pool for GitHub Actions Terraform pipelines (${var.environment})"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    # GitHub only puts `environment` in the token of a job that declares
    # `environment:`. Pull-request plans never do, so they map to "none" and can
    # never match the deployer binding below.
    "attribute.environment" = "has(assertion.environment) ? assertion.environment : 'none'"
  }

  # Only tokens from THIS repository are accepted. Without this condition the
  # provider would trust any GitHub repo's OIDC token.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ============================================
# Plan service account — read-only (pull requests)
# ============================================
#
# The same split as eks-terraform's plan/deploy roles. terraform-plan runs on
# pull requests, whose workflow file comes from the PR's own branch, so the
# identity it can reach must not be able to change anything.

resource "google_service_account" "plan" {
  account_id   = "tf-plan-${var.environment}"
  display_name = "Terraform CI plan, read-only (${var.environment})"
}

resource "google_project_iam_member" "plan" {
  for_each = toset(var.plan_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

# Any workflow of this repository may plan — including pull requests.
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Read state only. The plan runs with -lock=false, so it never writes a lock
# object either.
resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = local.state_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.plan.email}"
}

# ============================================
# Deployer service account — write (deploy/destroy only)
# ============================================

resource "google_service_account" "deployer" {
  account_id   = "tf-deployer-${var.environment}"
  display_name = "Terraform CI deployer (${var.environment})"
}

# Grant the deployer the project-level roles the layers need.
resource "google_project_iam_member" "deployer" {
  for_each = toset(var.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Only a job that declares `environment: <env>` can impersonate the deployer.
# That claim is minted by GitHub, gated by the Environment's protection rules
# (required reviewer on prod, deployment-branch policy), and cannot be forged by
# a pull request editing its own workflow file.
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.environment/${var.environment}"
}

# Grant the deployer access to the pre-existing, unmanaged Terraform state bucket
# so the gcs backend can list/read/write state. This is an additive binding on a
# bucket Terraform does not own — needed because the bucket may live outside this
# project's IAM scope (and to be explicit even when it doesn't).
resource "google_storage_bucket_iam_member" "deployer_state" {
  bucket = local.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.deployer.email}"
}
