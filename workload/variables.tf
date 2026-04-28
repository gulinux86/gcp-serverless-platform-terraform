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

variable "vpc_network_id" {
  type        = string
  description = "VPC network ID"
}

variable "private_subnet_id" {
  type        = string
  description = "Private Subnet ID for Direct VPC Egress"
}

variable "vpc_peering_id" {
  type        = string
  description = "VPC Peering/PSA connection ID for explicit dependency"
}

variable "domain_name" {
  type        = string
  description = "Custom domain for HTTPS load balancer and managed SSL certificate (optional)"
  default     = null
  nullable    = true
}

variable "db_tier" {
  type        = string
  description = "Cloud SQL instance tier (e.g., db-f1-micro, db-g1-small)"
  default     = "db-f1-micro"
}

variable "db_availability_type" {
  type        = string
  description = "Cloud SQL availability type: ZONAL (single-zone) or REGIONAL (HA with standby replica)"
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.db_availability_type)
    error_message = "db_availability_type must be ZONAL or REGIONAL."
  }
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the Cloud SQL instance. Set true for PROD."
  default     = false
}
