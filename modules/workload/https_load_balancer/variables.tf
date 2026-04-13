variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Cloud Run service region"
  type        = string
}

variable "name" {
  description = "Base name for load balancer resources"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to front with this load balancer"
  type        = string
}

variable "domain" {
  description = "Custom domain for the managed SSL certificate (optional)"
  type        = string
  default     = null
  nullable    = true
}

variable "security_policy_id" {
  description = "Cloud Armor security policy self_link to attach to the backend service (optional)"
  type        = string
  default     = null
  nullable    = true
}

variable "api_cloud_run_service_name" {
  description = "Name of the Cloud Run service for the API backend. When set, enables path-based routing: api_path_prefix/* → this service, default → cloud_run_service_name."
  type        = string
  default     = null
  nullable    = true
}

variable "api_path_prefix" {
  description = "URL path prefix to route to the API backend (e.g., /api). Only used when api_cloud_run_service_name is set."
  type        = string
  default     = "/api"
}
