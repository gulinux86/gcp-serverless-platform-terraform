resource "google_secret_manager_secret" "this" {
  secret_id = var.secret_id

  replication {
    auto {
    }
  }

  dynamic "rotation" {
    for_each = var.rotation_period != null ? [1] : []
    content {
      rotation_period    = var.rotation_period
      next_rotation_time = timeadd(timestamp(), var.rotation_period)
    }
  }

  dynamic "topics" {
    for_each = var.rotation_topic_id != null ? [1] : []
    content {
      name = var.rotation_topic_id
    }
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "this" {
  count = var.secret_value != null ? 1 : 0

  secret      = google_secret_manager_secret.this.id
  secret_data = var.secret_value
}

