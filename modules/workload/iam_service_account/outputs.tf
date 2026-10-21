output "email" {
  description = "Service account email"
  value       = google_service_account.this.email
}

output "name" {
  description = "Fully qualified service account name (projects/PROJECT/serviceAccounts/EMAIL)"
  value       = google_service_account.this.name
}

output "unique_id" {
  description = "Service account unique numeric ID"
  value       = google_service_account.this.unique_id
}

output "key_id" {
  description = "Service account key ID (null when create_key = false)"
  value       = var.create_key ? google_service_account_key.this[0].id : null
}

