resource "google_cloud_run_v2_service" "this" {
  name                = var.name
  location            = var.region
  deletion_protection = false
  ingress             = var.ingress

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instance_count
    }

    # Direct VPC Egress: the service attaches a network interface straight to the
    # private subnet. No Serverless VPC Access Connector sits in the path — one
    # less managed component, no connector cost, and no connector health
    # dependency. The trade-off is one purpose=SERVERLESS address reservation per
    # subnet attachment, which GCP releases asynchronously (measured at 1h+) and
    # which blocks subnet deletion until it does. No cooldown here can shorten
    # that; the destroy pipeline's serverless IP-release gate waits it out.
    # See docs/runbooks/serverless-ipv4-reservation.md
    dynamic "vpc_access" {
      for_each = var.vpc_subnet_id != null ? [1] : []
      content {
        network_interfaces {
          subnetwork = var.vpc_subnet_id
        }
        egress = "ALL_TRAFFIC"
      }
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
