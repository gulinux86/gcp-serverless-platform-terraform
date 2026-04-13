resource "google_storage_bucket" "this" {
  name          = var.name
  location      = var.location
  force_destroy = var.force_destroy

  uniform_bucket_level_access = var.uniform_bucket_level_access

  versioning {
    enabled = var.versioning_enabled
  }

  lifecycle_rule {
    condition {
      age = var.lifecycle_age
    }
    action {
      type = var.lifecycle_action
    }
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "public" {
  count  = var.public_access ? 1 : 0
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

