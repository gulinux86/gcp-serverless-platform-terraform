variable "secret_id" {
  description = "Secret ID (unique name)"
  type        = string
}

variable "secret_value" {
  description = "Secret value (optional, can be defined later)"
  type        = string
  default     = null
  sensitive   = true
}

variable "labels" {
  description = "Secret labels"
  type        = map(string)
  default     = {}
}

variable "rotation_period" {
  description = "ISO 8601 duration for automatic rotation notifications, e.g. '2592000s' for 30 days"
  type        = string
  default     = null
  nullable    = true
}

variable "rotation_topic_id" {
  description = "Pub/Sub topic ID to receive rotation notifications"
  type        = string
  default     = null
  nullable    = true
}
