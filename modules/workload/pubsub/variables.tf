variable "topic_name" {
  description = "Pub/Sub topic name"
  type        = string
}

variable "subscription_name" {
  description = "Subscription name (optional, defaults to topic_name-sub)"
  type        = string
  default     = null
}

variable "create_subscription" {
  description = "Automatically create a subscription"
  type        = bool
  default     = true
}

variable "message_retention_duration" {
  description = "Message retention duration (e.g., 604800s for 7 days)"
  type        = string
  default     = "604800s"
}

variable "ack_deadline_seconds" {
  description = "ACK deadline in seconds"
  type        = number
  default     = 20
}

variable "subscription_ttl" {
  description = "Subscription TTL (e.g., 2592000s for 30 days)"
  type        = string
  default     = "2592000s"
}

variable "minimum_backoff" {
  description = "Minimum backoff in seconds"
  type        = string
  default     = "10s"
}

variable "maximum_backoff" {
  description = "Maximum backoff in seconds"
  type        = string
  default     = "600s"
}

variable "labels" {
  description = "Topic labels"
  type        = map(string)
  default     = {}
}
