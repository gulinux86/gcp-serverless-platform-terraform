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
