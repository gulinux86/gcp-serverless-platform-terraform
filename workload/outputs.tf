# Cloud Run Outputs
output "backend_service_url" {
  description = "Backend Cloud Run service URL"
  value       = module.backend.service_url
}

output "frontend_service_url" {
  description = "Frontend Cloud Run service URL"
  value       = module.frontend.service_url
}

output "serverless_decommission_signal" {
  description = "Combined signal for all serverless resources decommissioning"
  value = {
    backend  = module.backend.decommission_signal
    frontend = module.frontend.decommission_signal
  }
}

# Database Outputs
output "database_connection_name" {
  description = "Cloud SQL connection name (for Cloud SQL Proxy)"
  value       = module.database.connection_name
  sensitive   = true
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

# Service Account Outputs
output "backend_sa_email" {
  description = "Backend Service Account email"
  value       = module.backend_sa.email
}

output "frontend_sa_email" {
  description = "Frontend Service Account email"
  value       = module.frontend_sa.email
}

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "Global IP address of the HTTPS load balancer (point your domain DNS here)"
  value       = module.https_load_balancer.load_balancer_ip
}

# Artifact Registry Outputs
output "artifact_registry_id" {
  description = "Artifact Registry ID"
  value       = module.artifact_registry.repository_id
}
