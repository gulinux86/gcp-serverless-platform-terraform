output "name" {
  description = "Cluster name"
  value       = google_container_cluster.this.name
}

output "location" {
  description = "Cluster location (region or zone)"
  value       = google_container_cluster.this.location
}

output "id" {
  description = "Cluster ID"
  value       = google_container_cluster.this.id
}

output "dns_endpoint" {
  description = "IAM-authorised DNS endpoint of the control plane (hostname, no scheme). Served with a publicly trusted certificate, so clients need no cluster CA."
  value       = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "private_endpoint" {
  description = "Internal IP of the control plane, reachable only from inside the VPC"
  value       = google_container_cluster.this.private_cluster_config[0].private_endpoint
}

output "workload_identity_pool" {
  description = "Workload Identity pool, used to build KSA members: serviceAccount:<pool>[<namespace>/<ksa>]"
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}
