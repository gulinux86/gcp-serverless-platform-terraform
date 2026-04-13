output "topic_name" {
  description = "Pub/Sub topic name"
  value       = google_pubsub_topic.this.name
}

output "topic_id" {
  description = "Pub/Sub topic ID"
  value       = google_pubsub_topic.this.id
}

output "subscription_name" {
  description = "Pub/Sub subscription name"
  value       = var.create_subscription ? google_pubsub_subscription.this[0].name : null
}

output "subscription_id" {
  description = "Pub/Sub subscription ID"
  value       = var.create_subscription ? google_pubsub_subscription.this[0].id : null
}
