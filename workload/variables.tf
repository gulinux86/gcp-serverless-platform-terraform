variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "name" {
  type        = string
  description = "Human-readable name prefix for all GCP resources"
}

variable "region" {
  type        = string
  description = "Default region"
  default     = "us-central1"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "api_secret_key" {
  type        = string
  description = "API secret key"
  sensitive   = true
}

# Networking attributes (vpc_network_id, private_subnet_id, vpc_peering_id) are no
# longer injected by a root module. They are read from the foundation layer's
# remote state (see remote_state.tf) and exposed as locals in main.tf.

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding the Terraform state for all layers. Used to read the foundation layer's remote state."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. hml, prod). Selects the foundation remote-state prefix (<environment>/foundation)."
}

variable "domain_name" {
  type        = string
  description = "Custom domain for HTTPS load balancer and managed SSL certificate (optional)"
  default     = null
  nullable    = true
}
