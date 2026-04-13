variable "name" {
  description = "Name prefix for all resources in this module"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "handler_image" {
  description = "Container image for the secret rotation handler Cloud Run Job"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}

variable "ack_deadline_seconds" {
  description = "Pub/Sub subscription acknowledgement deadline in seconds"
  type        = number
  default     = 60
}

variable "message_retention_duration" {
  description = "Pub/Sub subscription message retention duration"
  type        = string
  default     = "600s"
}
