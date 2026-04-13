output "email" {
  description = "Email da service account"
  value       = google_service_account.this.email
}

output "name" {
  description = "Nome completo da service account"
  value       = google_service_account.this.name
}

output "unique_id" {
  description = "ID único da service account"
  value       = google_service_account.this.unique_id
}

output "key_id" {
  description = "ID da chave (se criada)"
  value       = var.create_key ? google_service_account_key.this[0].id : null
}

