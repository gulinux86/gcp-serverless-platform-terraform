# ============================================
# Local: select the active URL map
# ============================================

locals {
  url_map_self_link = var.api_cloud_run_service_name != null ? google_compute_url_map.with_api[0].self_link : google_compute_url_map.this[0].self_link
}

# ============================================
# Global IP Address
# ============================================

resource "google_compute_global_address" "this" {
  name    = "${var.name}-ip"
  project = var.project_id
}

# ============================================
# Serverless NEG (frontend Cloud Run service)
# ============================================

resource "google_compute_region_network_endpoint_group" "this" {
  name                  = "${var.name}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# Serverless NEG for the API backend (optional)
resource "google_compute_region_network_endpoint_group" "api" {
  count = var.api_cloud_run_service_name != null ? 1 : 0

  name                  = "${var.name}-api-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.api_cloud_run_service_name
  }
}

# ============================================
# Backend Services
# ============================================

resource "google_compute_backend_service" "this" {
  name                  = "${var.name}-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = var.security_policy_id != null ? var.security_policy_id : null

  backend {
    group = google_compute_region_network_endpoint_group.this.self_link
  }
}

# Backend service for the API (optional — created when api_cloud_run_service_name is set)
resource "google_compute_backend_service" "api" {
  count = var.api_cloud_run_service_name != null ? 1 : 0

  name                  = "${var.name}-api-backend"
  project               = var.project_id
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = var.security_policy_id != null ? var.security_policy_id : null

  backend {
    group = google_compute_region_network_endpoint_group.api[0].self_link
  }
}

# ============================================
# URL Map
# ============================================

# Simple URL map (single backend — no API routing configured)
resource "google_compute_url_map" "this" {
  count = var.api_cloud_run_service_name == null ? 1 : 0

  name            = "${var.name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.this.self_link
}

# Path-based URL map (frontend default + API path routing)
resource "google_compute_url_map" "with_api" {
  count = var.api_cloud_run_service_name != null ? 1 : 0

  name            = "${var.name}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.this.self_link

  host_rule {
    hosts        = ["*"]
    path_matcher = "routes"
  }

  path_matcher {
    name            = "routes"
    default_service = google_compute_backend_service.this.self_link

    path_rule {
      paths   = ["${var.api_path_prefix}", "${var.api_path_prefix}/*"]
      service = google_compute_backend_service.api[0].self_link
    }
  }
}

# ============================================
# Managed SSL Certificate
# ============================================

resource "google_compute_managed_ssl_certificate" "this" {
  count   = var.domain != null ? 1 : 0
  name    = "${var.name}-cert"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

# ============================================
# HTTPS Proxy (only when domain is configured)
# ============================================

resource "google_compute_target_https_proxy" "this" {
  count = var.domain != null ? 1 : 0

  name             = "${var.name}-https-proxy"
  project          = var.project_id
  url_map          = local.url_map_self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.this[0].self_link]
}

# ============================================
# HTTP Proxy
# When domain is set: redirects HTTP → HTTPS
# When domain is null: routes HTTP directly (dev mode, no TLS)
# ============================================

# Always exists to avoid destroy/re-create races on the target_http_proxy.
# Behavior: HTTPS redirect when domain is set, plain routing otherwise.
resource "google_compute_url_map" "redirect" {
  name    = "${var.name}-http-redirect"
  project = var.project_id

  dynamic "default_url_redirect" {
    for_each = var.domain != null ? [1] : []
    content {
      https_redirect         = true
      strip_query            = false
      redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    }
  }

  # When no domain: route straight to the main backend (HTTP only, dev mode)
  default_service = var.domain == null ? google_compute_backend_service.this.self_link : null
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${var.name}-http-proxy"
  project = var.project_id
  url_map = var.domain != null ? google_compute_url_map.redirect.self_link : local.url_map_self_link
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name}-http"
  project               = var.project_id
  target                = google_compute_target_http_proxy.redirect.self_link
  port_range            = "80"
  ip_address            = google_compute_global_address.this.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ============================================
# Global Forwarding Rule (HTTPS — only when domain is configured)
# ============================================

resource "google_compute_global_forwarding_rule" "https" {
  count = var.domain != null ? 1 : 0

  name                  = "${var.name}-https"
  project               = var.project_id
  target                = google_compute_target_https_proxy.this[0].self_link
  port_range            = "443"
  ip_address            = google_compute_global_address.this.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
