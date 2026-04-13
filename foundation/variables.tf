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

variable "domain_name" {
  type        = string
  description = "Domain name for DNS (Optional)"
  default     = null
}

variable "serverless_decommission_signal" {
  type        = map(string)
  description = "Signal from the workload layer indicating serverless resources have completed their cooldown. Used to enforce destruction ordering: workload cooldown -> subnet deletion."
  default     = null
  nullable    = true
}
