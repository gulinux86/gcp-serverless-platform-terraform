# ============================================
# Data Sources and Inputs
# ============================================

# VPC configuration passed from foundation module via root orchestration

# ============================================
# IAM and Service Accounts (Fine-grained PoLP)
# ============================================

# Service Account for Backend API
module "backend_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "backend-sa"
  display_name = "Backend Service Account"
  project_id   = var.project_id

  iam_roles = {
    "roles/cloudsql.client"      = "roles/cloudsql.client"
    "roles/storage.objectViewer" = "roles/storage.objectViewer"
  }
}

# Service Account for Frontend App
module "frontend_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "frontend-sa"
  display_name = "Frontend Service Account"
  project_id   = var.project_id

  iam_roles = {
    "roles/storage.objectViewer" = "roles/storage.objectViewer"
  }
}

# ============================================
# CI/CD and Artifacts
# ============================================

module "artifact_registry" {
  source = "../modules/workload/artifact_registry"

  repository_id = "${var.name}-services"
  location      = var.region
  format        = "DOCKER"
}

# ============================================
# Data Storage
# ============================================

module "database" {
  source = "../modules/workload/cloud_sql"

  name                = "${var.name}-db"
  region              = var.region
  database_name       = "appdb"
  db_user             = "appuser"
  db_password         = var.db_password
  tier                = "db-f1-micro"
  availability_type   = "REGIONAL"
  public_ip           = false
  deletion_protection = false
  vpc_network_id      = var.vpc_network_id
  vpc_peering_id      = var.vpc_peering_id
}

module "storage" {
  source = "../modules/workload/cloud_storage"

  name     = "${var.name}-storage-${var.project_id}"
  location = var.region
}

# ============================================
# Secrets
# ============================================

# Secret rotation infrastructure (Pub/Sub topic, IAM, Cloud Run Job, push subscription)
module "secret_rotation" {
  source = "../modules/workload/secret_rotation"

  name       = var.name
  project_id = var.project_id
  region     = var.region
}

# State migration: rename inline resources to module-scoped addresses.
# Remove these moved blocks after the first successful apply.
moved {
  from = google_pubsub_topic.secret_rotation
  to   = module.secret_rotation.google_pubsub_topic.this
}

moved {
  from = google_pubsub_topic_iam_member.secretmanager_can_publish
  to   = module.secret_rotation.google_pubsub_topic_iam_member.this
}

moved {
  from = google_cloud_run_v2_job.secret_rotation_handler
  to   = module.secret_rotation.google_cloud_run_v2_job.this
}

moved {
  from = google_pubsub_subscription.secret_rotation_push
  to   = module.secret_rotation.google_pubsub_subscription.this
}

module "app_secret" {
  source = "../modules/workload/secret_manager"

  secret_id         = "app-api-key"
  secret_value      = var.api_secret_key
  rotation_period   = "2592000s"
  rotation_topic_id = module.secret_rotation.topic_id
}

module "db_password_secret" {
  source = "../modules/workload/secret_manager"

  secret_id         = "db-password"
  secret_value      = var.db_password
  rotation_period   = "2592000s"
  rotation_topic_id = module.secret_rotation.topic_id
}

# Per-secret IAM: backend-sa can only access its own secrets (PoLP)
resource "google_secret_manager_secret_iam_member" "backend_sa_app_secret" {
  secret_id = module.app_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.backend_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "backend_sa_db_password" {
  secret_id = module.db_password_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.backend_sa.email}"
}

# ============================================
# Computing - Cloud Run Services
# ============================================

# Workload-level IP release guard: ensures all Direct VPC Egress IP reservations
# are released before the workload module completes teardown.
# Destroy order: Cloud Run modules destroyed → this timer waits 150s → workload done.
# This fires regardless of whether per-service timers exist in state.
resource "time_sleep" "vpc_egress_release_guard" {
  destroy_duration = "150s"
}

# Backend API Service
module "backend" {
  source = "../modules/workload/cloud_run_service"

  depends_on = [time_sleep.vpc_egress_release_guard]

  name               = "backend"
  region             = var.region
  image              = "gcr.io/cloudrun/hello"
  ingress            = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  make_public        = false
  min_instance_count = 1

  service_account_email = module.backend_sa.email
  vpc_subnet_id         = var.private_subnet_id
  gcs_bucket_name       = module.storage.bucket_name

  env_vars = {
    DATABASE_URL = "postgresql://appuser@/${module.database.database_name}?host=/cloudsql/${module.database.connection_name}"
    SECRET_NAME  = module.app_secret.secret_name
  }

  secret_env_vars = {
    DB_PASSWORD = {
      secret  = module.db_password_secret.secret_name
      version = "latest"
    }
  }
}

# Frontend App Service
module "frontend" {
  source = "../modules/workload/cloud_run_service"

  depends_on = [time_sleep.vpc_egress_release_guard]

  name               = "frontend"
  region             = var.region
  image              = "gcr.io/cloudrun/hello"
  ingress            = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  min_instance_count = 1

  service_account_email = module.frontend_sa.email
  vpc_subnet_id         = var.private_subnet_id

}


# ============================================
# Cloud Armor WAF Security Policy
# ============================================

module "cloud_armor" {
  source = "../modules/workload/cloud_armor"

  project_id = var.project_id
  name       = "${var.name}-armor"
}

# ============================================
# Global HTTPS Load Balancer
# ============================================

module "https_load_balancer" {
  source = "../modules/workload/https_load_balancer"

  project_id                 = var.project_id
  region                     = var.region
  name                       = "${var.name}-lb"
  cloud_run_service_name     = module.frontend.name
  api_cloud_run_service_name = module.backend.name
  domain                     = var.domain_name
  security_policy_id         = module.cloud_armor.security_policy_self_link
}

# ============================================
# Observability — Cloud Monitoring Alerts
# ============================================

resource "google_monitoring_alert_policy" "frontend_error_rate" {
  display_name = "${var.name} - Frontend High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run frontend error rate > 1%"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"frontend\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.01
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "frontend_latency" {
  display_name = "${var.name} - Frontend High Latency"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run frontend p99 latency > 2000ms"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"frontend\" AND metric.type = \"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2000
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_99"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "cloudsql_disk" {
  display_name = "${var.name} - Cloud SQL Disk Usage High"
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL disk utilization > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# ============================================
# Observability — Audit Log Sink
# ============================================

resource "google_storage_bucket" "audit_logs" {
  name                        = "${var.name}-audit-logs-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
}

resource "google_logging_project_sink" "audit_logs" {
  name                   = "${var.name}-audit-sink"
  destination            = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  filter                 = "logName:(\"cloudaudit.googleapis.com\")"
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "audit_sink_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit_logs.writer_identity
}

