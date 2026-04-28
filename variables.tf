variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "name" {
  type        = string
  description = "Human-readable name prefix for all GCP resources"
  default     = "app"
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

variable "domain_name" {
  type        = string
  description = "Domain name for DNS (Optional)"
  default     = null
}

variable "db_tier" {
  type        = string
  description = "Cloud SQL instance tier (e.g., db-f1-micro, db-g1-small)"
  default     = "db-f1-micro"
}

variable "db_availability_type" {
  type        = string
  description = "Cloud SQL availability type: ZONAL or REGIONAL"
  default     = "ZONAL"
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the Cloud SQL instance"
  default     = false
}
