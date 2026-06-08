provider "google" {
  project = var.project_id
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
  }

  # Only tokens from THIS repository are accepted. Without this condition the
  # provider would trust any GitHub repo's OIDC token.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ============================================
# Deployer service account (impersonated by CI)
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

# Let the GitHub repo (via the WIF pool) impersonate the deployer SA.
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
