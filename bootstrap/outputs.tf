# Copy these values into GitHub secrets for this environment:
#   <ENV>_WIF_PROVIDER  <- workload_identity_provider
#   <ENV>_WIF_SA        <- deployer_service_account   (deploy / destroy)
#   <ENV>_PLAN_SA       <- plan_service_account       (plan, read-only)
# e.g. for hml: HML_WIF_PROVIDER, HML_WIF_SA, HML_PLAN_SA

output "workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth (workload_identity_provider)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "Deployer SA email for google-github-actions/auth (service_account). Only jobs with `environment: <env>` can impersonate it."
  value       = google_service_account.deployer.email
}

output "plan_service_account" {
  description = "Read-only plan SA email. Any workflow of the repository can impersonate it."
  value       = google_service_account.plan.email
}
