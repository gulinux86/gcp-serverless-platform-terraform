resource "google_cloud_run_v2_service" "this" {
  name                = var.name
  location            = var.region
  deletion_protection = false
  ingress             = var.ingress

  # Ensures the IP release cooldown is destroyed AFTER Cloud Run on terraform destroy.
  # Create order: timer → Cloud Run | Destroy order: Cloud Run → timer waits 150s
  depends_on = [time_sleep.wait_for_ip_release]

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instance_count
    }

    vpc_access {
      network_interfaces {
        subnetwork = var.vpc_subnet_id
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      image = var.image

      resources {
        limits = {
          memory = var.memory
          cpu    = var.cpu
        }
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      dynamic "volume_mounts" {
        for_each = var.gcs_bucket_name != null ? [1] : []
        content {
          name       = "gcs-bucket"
          mount_path = var.mount_path
        }
      }
    }

    dynamic "volumes" {
      for_each = var.gcs_bucket_name != null ? [1] : []
      content {
        name = "gcs-bucket"
        gcs {
          bucket    = var.gcs_bucket_name
          read_only = false
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "noauth" {
  count = var.make_public ? 1 : 0

  location = google_cloud_run_v2_service.this.location
  project  = google_cloud_run_v2_service.this.project
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cooldown to ensure GCP releases Direct VPC Egress IP reservations after destruction.
# Destroy order: Cloud Run deleted → timer waits → module fully destroyed.
# Foundation's subnet can only be deleted after the workload module (including this timer) is gone.
resource "time_sleep" "wait_for_ip_release" {
  destroy_duration = "150s"
}
