output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.this.id
}

output "private_subnet_name" {
  description = "Private subnet name"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = google_compute_subnetwork.private.id
}

output "psa_range_name" {
  description = "PSA range name"
  value       = google_compute_global_address.private_ip_alloc.name
}

output "psa_connection_id" {
  description = "PSA connection ID"
  value       = google_service_networking_connection.default.id
}

output "secondary_subnet_name" {
  description = "Secondary private subnet name"
  value       = google_compute_subnetwork.private_2.name
}

output "secondary_subnet_id" {
  description = "Secondary private subnet ID"
  value       = google_compute_subnetwork.private_2.id
}
