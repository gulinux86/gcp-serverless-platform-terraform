# Copy these two values into GitHub secrets for this environment:
#   <ENV>_WIF_PROVIDER  <- workload_identity_provider
#   <ENV>_DEPLOYER_SA   <- deployer_service_account
# e.g. for hml: HML_WIF_PROVIDER, HML_DEPLOYER_SA

output "workload_identity_provider" {
  description = "Full provider resource name for google-github-actions/auth (workload_identity_provider)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "Deployer SA email for google-github-actions/auth (service_account)."
  value       = google_service_account.deployer.email
}
