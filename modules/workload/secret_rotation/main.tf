# ============================================
# Secret Rotation Infrastructure
# ============================================
# Owns the full rotation loop:
#   Pub/Sub topic → Secret Manager service agent IAM
#   → Cloud Run Job handler → Pub/Sub push subscription

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_service_account" "invoker" {
  account_id   = "${var.name}-rotation-invoker"
  display_name = "Secret Rotation Push Invoker"
  project      = var.project_id
}

resource "google_pubsub_topic" "this" {
  name    = "${var.name}-secret-rotation"
  project = var.project_id
}

# Allow Secret Manager service agent to publish rotation notifications
resource "google_pubsub_topic_iam_member" "this" {
  topic   = google_pubsub_topic.this.name
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_job" "this" {
  name               = "${var.name}-secret-rotation-handler"
  project            = var.project_id
  location           = var.region
  deletion_protection = false

  template {
    template {
      containers {
        image = var.handler_image
      }
    }
  }
}

resource "google_cloud_run_v2_job_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.invoker.email}"
}

resource "google_pubsub_subscription" "this" {
  name    = "${var.name}-secret-rotation-push"
  topic   = google_pubsub_topic.this.name
  project = var.project_id

  push_config {
    push_endpoint = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.this.name}:run"

    oidc_token {
      service_account_email = google_service_account.invoker.email
      audience              = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.this.name}:run"
    }
  }

  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention_duration
}
