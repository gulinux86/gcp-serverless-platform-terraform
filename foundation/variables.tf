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
