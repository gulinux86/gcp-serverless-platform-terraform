output "topic_id" {
  description = "Full resource ID of the secret rotation Pub/Sub topic. Safe to use as a Secret Manager rotation topic: consumers of this output also wait for the publisher IAM binding."
  value       = google_pubsub_topic.this.id

  # The topic alone is not enough. Creating a google_secret_manager_secret with a
  # `topics` block makes the API verify, synchronously, that the Secret Manager
  # service agent can publish to it. Without this edge Terraform may create the
  # secret as soon as the topic exists — before the IAM binding — and the apply
  # fails with:
  #
  #   Error creating Secret: Permission 'pubsub.topics.publish' denied for
  #   service-<n>@gcp-sa-secretmanager.iam.gserviceaccount.com
  #
  # The race is invisible on incremental applies (the binding already exists) and
  # only shows up on a clean create, which is why it survived until the first full
  # teardown-and-rebuild cycle.
  depends_on = [google_pubsub_topic_iam_member.this]
}

output "topic_name" {
  description = "Name of the secret rotation Pub/Sub topic"
  value       = google_pubsub_topic.this.name
}

output "invoker_sa_email" {
  description = "Email of the service account used to authenticate Pub/Sub push to the rotation handler job"
  value       = google_service_account.invoker.email
}
