output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}

output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.this.id
}

output "private_subnet_name" {
  description = "Node subnet name"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_id" {
  description = "Node subnet ID"
  value       = google_compute_subnetwork.private.id
}

output "pods_range_name" {
  description = "Name of the secondary range GKE allocates pod IPs from"
  value       = google_compute_subnetwork.private.secondary_ip_range[0].range_name
}

output "services_range_name" {
  description = "Name of the secondary range GKE allocates Service ClusterIPs from"
  value       = google_compute_subnetwork.private.secondary_ip_range[1].range_name
}

output "psa_range_name" {
  description = "PSA range name"
  value       = google_compute_global_address.private_ip_alloc.name
}

output "psa_connection_id" {
  description = "PSA connection ID"
  value       = google_service_networking_connection.default.id
}
