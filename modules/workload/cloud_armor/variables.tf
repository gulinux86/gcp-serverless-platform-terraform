variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "name" {
  description = "Base name for load balancer resources"
  type        = string
}

variable "rate_limit_threshold" {
  description = "Maximum requests per minute per IP before rate limiting kicks in"
  type        = number
  default     = 100
}
