output "connection_name" {
  description = "Instance connection name (project:region:instance). Not needed for private-IP access; useful for the Cloud SQL Auth Proxy or connectors."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  description = "Instance private IP address"
  value       = google_sql_database_instance.this.private_ip_address
}

output "public_ip" {
  description = "Instance public IP address (always empty: the module hardcodes ipv4_enabled = false)"
  value       = google_sql_database_instance.this.public_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.this.name
}

output "db_user" {
  description = "Database user"
  value       = google_sql_user.this.name
}
