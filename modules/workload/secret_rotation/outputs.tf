output "topic_id" {
  description = "Full resource ID of the secret rotation Pub/Sub topic"
  value       = google_pubsub_topic.this.id
}

output "topic_name" {
  description = "Name of the secret rotation Pub/Sub topic"
  value       = google_pubsub_topic.this.name
}

output "invoker_sa_email" {
  description = "Email of the service account used to authenticate Pub/Sub push to the rotation handler job"
  value       = google_service_account.invoker.email
}
