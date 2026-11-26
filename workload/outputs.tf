# Database Outputs
output "database_connection_name" {
  description = "Cloud SQL connection name (for the Cloud SQL Auth Proxy sidecar: instanceConnectionName)"
  value       = module.database.connection_name
  sensitive   = true
}

output "database_private_ip" {
  description = "Cloud SQL private IP (PSA)"
  value       = module.database.private_ip
}

# Storage Outputs
output "storage_bucket_name" {
  description = "Cloud Storage bucket name"
  value       = module.storage.bucket_name
}

# Secret Manager Outputs
output "secret_name" {
  description = "Secret name"
  value       = module.app_secret.secret_name
  sensitive   = true
}

# Service Account Outputs — the emails the GitOps charts annotate their KSAs with
# (iam.gke.io/gcp-service-account).
output "backend_sa_email" {
  description = "Backend Service Account email"
  value       = module.backend_sa.email
}

output "frontend_sa_email" {
  description = "Frontend Service Account email"
  value       = module.frontend_sa.email
}

output "external_secrets_sa_email" {
  description = "External Secrets Operator service account email"
  value       = module.external_secrets_sa.email
}

# Edge Outputs — referenced by name from the Gateway / GCPBackendPolicy in Git.
output "gateway_address_name" {
  description = "Static IP name for the Gateway annotation networking.gke.io/addresses"
  value       = google_compute_global_address.gateway.name
}

output "load_balancer_ip" {
  description = "Static IP the Gateway's load balancer serves on (point your domain DNS here)"
  value       = google_compute_global_address.gateway.address
}

output "gateway_certificate_name" {
  description = "Managed certificate name for the Gateway option networking.gke.io/pre-shared-certs (null without domain_name)"
  value       = one(google_compute_managed_ssl_certificate.gateway[*].name)
}

output "cloud_armor_policy_name" {
  description = "Cloud Armor policy name for GCPBackendPolicy spec.default.securityPolicy"
  value       = module.cloud_armor.security_policy_name
}

# Artifact Registry Outputs
output "artifact_registry_id" {
  description = "Artifact Registry ID"
  value       = module.artifact_registry.repository_id
}

# Argo CD Outputs
output "argocd_port_forward_command" {
  description = "The Argo CD UI is not exposed; reach it through this port-forward"
  value       = module.argocd.port_forward_command
}

output "argocd_initial_password_command" {
  description = "Retrieves the generated admin password (a bootstrap credential — rotate it)"
  value       = module.argocd.initial_password_command
}
