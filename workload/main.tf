# ============================================
# Data Sources and Inputs
# ============================================

# Foundation attributes, read from the foundation layer's remote state (see
# remote_state.tf). Note the name reconciliation: foundation exports
# psa_connection_id, which the workload consumes as vpc_peering_id.
locals {
  vpc_network_id         = data.terraform_remote_state.foundation.outputs.vpc_network_id
  vpc_peering_id         = data.terraform_remote_state.foundation.outputs.psa_connection_id
  workload_identity_pool = data.terraform_remote_state.foundation.outputs.workload_identity_pool
}

# ============================================
# IAM and Service Accounts (Fine-grained PoLP)
# ============================================
#
# One Google SA per workload, reached from its Kubernetes SA through Workload
# Identity. The KSA names are a contract with the GitOps repository: the chart
# creates the KSA and annotates it with the GSA email; this layer grants the
# binding. A mismatch fails closed — the pod simply gets no Google credentials.

# Service Account for Backend API
module "backend_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "backend-sa"
  display_name = "Backend Service Account"
  project_id   = var.project_id

  # Storage access is granted on the app bucket only (see backend_sa_storage),
  # not project-wide — a project-level grant would also expose the audit logs.
  iam_roles = {
    "roles/cloudsql.client" = "roles/cloudsql.client"
  }

  workload_identity_pool = local.workload_identity_pool
  workload_identity_ksas = var.backend_ksas
}

# Service Account for Frontend App. No roles: it exists so the frontend pods
# run as an identity of their own instead of falling back to the node SA.
module "frontend_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "frontend-sa"
  display_name = "Frontend Service Account"
  project_id   = var.project_id

  workload_identity_pool = local.workload_identity_pool
  workload_identity_ksas = var.frontend_ksas
}

# External Secrets Operator: syncs Secret Manager → Kubernetes Secrets. Holds
# accessor on the listed secrets only (see the per-secret bindings below).
module "external_secrets_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "external-secrets-sa"
  display_name = "External Secrets Operator"
  project_id   = var.project_id

  workload_identity_pool = local.workload_identity_pool
  workload_identity_ksas = var.external_secrets_ksas
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
  deletion_protection = false
  vpc_network_id      = local.vpc_network_id
  vpc_peering_id      = local.vpc_peering_id
}

module "storage" {
  source = "../modules/workload/cloud_storage"

  name     = "${var.name}-storage-${var.project_id}"
  location = var.region
}

# The backend reads and writes objects in this bucket through the GCS API, as
# backend-sa via Workload Identity — objectUser, scoped to this bucket only.
resource "google_storage_bucket_iam_member" "backend_sa_storage" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.backend_sa.email}"
}

# ============================================
# Secrets
# ============================================

# Delivered to pods by External Secrets Operator (ExternalSecret → K8s Secret).
# Automatic rotation is not wired: the previous rotation handler was a Cloud
# Run Job, removed with the move to GKE (ARCHITECTURE.md §Secrets).
module "app_secret" {
  source = "../modules/workload/secret_manager"

  secret_id    = "app-api-key"
  secret_value = var.api_secret_key
}

module "db_password_secret" {
  source = "../modules/workload/secret_manager"

  secret_id    = "db-password"
  secret_value = var.db_password
}

# Per-secret IAM (PoLP): ESO reads both to materialise them in the cluster;
# backend-sa keeps direct access to the API key it reads at runtime.
resource "google_secret_manager_secret_iam_member" "external_secrets" {
  for_each = {
    app_secret  = module.app_secret.secret_id
    db_password = module.db_password_secret.secret_id
  }

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.external_secrets_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "backend_sa_app_secret" {
  secret_id = module.app_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.backend_sa.email}"
}

# ============================================
# Edge — consumed by the Gateway declared in Git
# ============================================
#
# The load balancer itself is no longer Terraform's: the GKE Gateway controller
# builds it from the Gateway/HTTPRoute in the GitOps repository. Terraform owns
# what must outlive a re-sync or is security policy rather than routing — the
# static IP, the WAF policy and the certificate — and exports their names for
# the Gateway (networking.gke.io/addresses, pre-shared-certs) and the
# GCPBackendPolicy (securityPolicy) to reference.

module "cloud_armor" {
  source = "../modules/workload/cloud_armor"

  project_id = var.project_id
  name       = "${var.name}-armor"
}

resource "google_compute_global_address" "gateway" {
  name         = "${var.name}-gateway-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

resource "google_compute_managed_ssl_certificate" "gateway" {
  count = var.domain_name != null ? 1 : 0

  name = "${var.name}-gateway-cert"

  managed {
    domains = [var.domain_name]
  }
}

# ============================================
# GitOps — Argo CD
# ============================================

# Installed bare: CRDs and controllers, no Application. Reached through the
# cluster's DNS endpoint (provider.tf), so CI needs no network path into the VPC.
module "argocd" {
  source        = "../modules/workload/argocd"
  chart_version = var.argocd_chart_version
}

# The handover: Terraform creates the privilege boundary and one root Application,
# then stops. Everything else reaches the cluster through Argo CD, from Git.
module "argocd_bootstrap" {
  source    = "../modules/workload/argocd_bootstrap"
  namespace = module.argocd.namespace

  platform_repo_url      = var.platform_repo_url
  platform_repo_revision = var.platform_repo_revision
  platform_repo_path     = var.platform_repo_path
  apps_repo_url          = var.apps_repo_url
  platform_source_repos  = var.platform_source_repos
  apps_source_repos      = var.apps_source_repos
  apps_namespaces        = var.apps_namespaces

  # The projects and the root app are meaningless until Argo CD's CRDs exist.
  depends_on = [module.argocd]
}

# ============================================
# Observability — Cloud Monitoring Alerts
# ============================================
#
# The LB is created by the Gateway controller with generated names, so the LB
# alerts match every https_lb_rule in the project. Each environment runs in its
# own project, which makes that the platform's edge and nothing else.

resource "google_monitoring_alert_policy" "lb_error_rate" {
  display_name = "${var.name} - Edge High Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "HTTPS LB 5xx ratio > 1%"
    # Ratio condition: 5xx requests / all requests. Without the denominator the
    # threshold would compare a raw rate (0.01 req/s), not a percentage.
    condition_threshold {
      filter             = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\" AND metric.labels.response_code_class = 500"
      denominator_filter = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/request_count\""
      duration           = "300s"
      comparison         = "COMPARISON_GT"
      threshold_value    = 0.01
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
      denominator_aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "lb_latency" {
  display_name = "${var.name} - Edge High Latency"
  combiner     = "OR"

  conditions {
    display_name = "HTTPS LB p99 total latency > 2000ms"
    condition_threshold {
      filter          = "resource.type = \"https_lb_rule\" AND metric.type = \"loadbalancing.googleapis.com/https/total_latencies\""
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

resource "google_monitoring_alert_policy" "container_restarts" {
  display_name = "${var.name} - Container Restart Loop"
  combiner     = "OR"

  conditions {
    display_name = "Container restarted more than 5 times in 10 minutes"
    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.cluster_name = \"${data.terraform_remote_state.foundation.outputs.cluster_name}\" AND metric.type = \"kubernetes.io/container/restart_count\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_DELTA"
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
  # Audit logs outlive a prod teardown: destroy fails on a non-empty bucket
  # instead of silently deleting them. Non-prod envs are torn down routinely.
  force_destroy = var.environment != "prod"

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

