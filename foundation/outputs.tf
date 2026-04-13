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
  description = "Private subnet name"
  value       = module.vpc.private_subnet_name
}

output "private_subnet_id" {
  description = "Private subnet ID"
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

output "secondary_subnet_name" {
  description = "Secondary private subnet name"
  value       = module.vpc.secondary_subnet_name
}

output "secondary_subnet_id" {
  description = "Secondary private subnet ID"
  value       = module.vpc.secondary_subnet_id
}
