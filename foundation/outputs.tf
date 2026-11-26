# These outputs are the API the workload layer consumes through
# terraform_remote_state. scripts/check-layer-contract.sh fails CI when the
# workload references one that is not declared here.

# VPC Outputs
output "vpc_network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_network_id" {
  description = "VPC network ID"
  value       = module.vpc.network_id
}

output "private_subnet_name" {
  description = "Node subnet name"
  value       = module.vpc.private_subnet_name
}

output "private_subnet_id" {
  description = "Node subnet ID"
  value       = module.vpc.private_subnet_id
}

output "psa_range_name" {
  description = "PSA range name"
  value       = module.vpc.psa_range_name
}

output "psa_connection_id" {
  description = "PSA connection ID"
  value       = module.vpc.psa_connection_id
}

# GKE Outputs
output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.name
}

output "cluster_location" {
  description = "GKE cluster location (region or zone)"
  value       = module.gke.location
}

output "cluster_dns_endpoint" {
  description = "IAM-authorised DNS endpoint of the control plane. The workload layer's Helm provider and `gcloud container clusters get-credentials --dns-endpoint` both use it."
  value       = module.gke.dns_endpoint
}

output "workload_identity_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog)"
  value       = module.gke.workload_identity_pool
}

output "node_service_account_email" {
  description = "Node service account email"
  value       = module.node_sa.email
}

output "get_credentials_command" {
  description = "kubectl access through the DNS endpoint (needs container.clusters.connect)"
  value       = "gcloud container clusters get-credentials ${module.gke.name} --location ${module.gke.location} --project ${var.project_id} --dns-endpoint"
}
