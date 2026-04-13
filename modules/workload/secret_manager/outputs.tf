output "secret_id" {
  description = "Full secret resource ID (projects/PROJECT/secrets/SECRET) — use for IAM bindings"
  value       = google_secret_manager_secret.this.id
}

output "secret_name" {
  description = "Full secret name"
  value       = google_secret_manager_secret.this.name
}

output "secret_version" {
  description = "Secret version (if created)"
  value       = var.secret_value != null ? google_secret_manager_secret_version.this[0].name : null
}
