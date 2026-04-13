resource "google_pubsub_topic" "this" {
  name   = var.topic_name
  labels = var.labels
}

resource "google_pubsub_subscription" "this" {
  count = var.create_subscription ? 1 : 0

  name  = var.subscription_name != null ? var.subscription_name : "${var.topic_name}-sub"
  topic = google_pubsub_topic.this.name

  message_retention_duration = var.message_retention_duration
  retain_acked_messages      = false
  ack_deadline_seconds       = var.ack_deadline_seconds

  expiration_policy {
    ttl = var.subscription_ttl
  }

  retry_policy {
    minimum_backoff = var.minimum_backoff
    maximum_backoff = var.maximum_backoff
  }
}
