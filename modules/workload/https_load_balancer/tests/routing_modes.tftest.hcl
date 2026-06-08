# routing_modes.tftest.hcl
#
# Trade-off context:
#   The https_load_balancer module has 4 distinct operating modes driven by two
#   optional variables (domain, api_cloud_run_service_name). Each combination
#   creates a different set of resources. Without tests for every combination:
#     - A refactor that breaks "domain + API" mode is invisible in code review
#     - Missing HTTPS resources produce no Terraform error — only a silent HTTP-only LB
#     - A broken url_map.with_api means API traffic silently falls to the frontend
#   The cost of testing all 4 modes here is ~1 second. The cost of missing one
#   is an outage or a security downgrade discovered in production.

mock_provider "google" {}

variables {
  project_id             = "test-project"
  region                 = "us-central1"
  name                   = "test-lb"
  cloud_run_service_name = "frontend-service"
}

# ── Mode 1: No domain, no API ─────────────────────────────────────────────────
# HTTP only. Used for internal or dev environments.
# Trade-off: no TLS, no path routing. Simpler, but not production-safe.

run "http_only_no_domain_no_api" {
  command = plan

  assert {
    condition     = length(google_compute_managed_ssl_certificate.this) == 0
    error_message = "No SSL certificate must be created when domain is not set."
  }

  assert {
    condition     = length(google_compute_target_https_proxy.this) == 0
    error_message = "No HTTPS proxy must be created when domain is not set."
  }

  assert {
    condition     = length(google_compute_global_forwarding_rule.https) == 0
    error_message = "No HTTPS forwarding rule must be created when domain is not set."
  }

  assert {
    condition     = length(google_compute_backend_service.api) == 0
    error_message = "No API backend service must be created when api_cloud_run_service_name is not set."
  }

  assert {
    condition     = length(google_compute_url_map.with_api) == 0
    error_message = "No path-based URL map must be created when API service is not set."
  }

  assert {
    condition     = length(google_compute_url_map.this) == 1
    error_message = "Simple (single-backend) URL map must be created when no API service is configured."
  }
}

# ── Mode 2: Domain set, no API ────────────────────────────────────────────────
# HTTPS enabled via managed SSL certificate + HTTP→HTTPS redirect.
# Trade-off: TLS termination at the LB layer, managed cert lifecycle by GCP.

run "tls_enabled_with_domain" {
  command = plan

  variables {
    domain = "app.example.com"
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.this) == 1
    error_message = "Managed SSL certificate must be created when domain is set."
  }

  assert {
    condition     = length(google_compute_target_https_proxy.this) == 1
    error_message = "HTTPS proxy must be created when domain is set."
  }

  assert {
    condition     = length(google_compute_global_forwarding_rule.https) == 1
    error_message = "HTTPS forwarding rule (port 443) must be created when domain is set."
  }

  assert {
    condition     = google_compute_managed_ssl_certificate.this[0].managed[0].domains[0] == "app.example.com"
    error_message = "SSL certificate must be issued for the configured domain."
  }
}

# ── Mode 3: No domain, API service set ────────────────────────────────────────
# Path-based routing without TLS. Used for internal multi-service environments.
# Trade-off: /api/* routes to API backend, everything else to frontend — no TLS.

run "api_path_routing_without_domain" {
  command = plan

  variables {
    api_cloud_run_service_name = "backend-api-service"
  }

  assert {
    condition     = length(google_compute_backend_service.api) == 1
    error_message = "API backend service must be created when api_cloud_run_service_name is set."
  }

  assert {
    condition     = length(google_compute_url_map.with_api) == 1
    error_message = "Path-based URL map must be created when API service is configured."
  }

  assert {
    condition     = length(google_compute_url_map.this) == 0
    error_message = "Simple URL map must NOT exist when path-based routing is active. Both url maps existing simultaneously would create a resource conflict."
  }

  assert {
    condition     = length(google_compute_region_network_endpoint_group.api) == 1
    error_message = "Serverless NEG for the API service must be created."
  }
}

# ── Mode 4: Domain + API (full production setup) ──────────────────────────────
# TLS + path-based routing. The standard production configuration.
# Trade-off: most complex setup, most resources created, highest cost.

run "full_production_setup_domain_and_api" {
  command = plan

  variables {
    domain                     = "app.example.com"
    api_cloud_run_service_name = "backend-api-service"
    api_path_prefix            = "/api"
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.this) == 1
    error_message = "SSL certificate must be created in full production mode."
  }

  assert {
    condition     = length(google_compute_target_https_proxy.this) == 1
    error_message = "HTTPS proxy must be created in full production mode."
  }

  assert {
    condition     = length(google_compute_backend_service.api) == 1
    error_message = "API backend service must be created in full production mode."
  }

  assert {
    condition     = length(google_compute_url_map.with_api) == 1
    error_message = "Path-based URL map must be created in full production mode."
  }

  assert {
    condition     = length(google_compute_url_map.this) == 0
    error_message = "Simple URL map must NOT be created alongside path-based URL map."
  }
}

# ── Security: Cloud Armor attachment ──────────────────────────────────────────

run "cloud_armor_attached_when_policy_provided" {
  command = plan

  variables {
    security_policy_id = "projects/test-project/global/securityPolicies/test-app-policy"
  }

  assert {
    condition     = google_compute_backend_service.this.security_policy == "projects/test-project/global/securityPolicies/test-app-policy"
    error_message = "Cloud Armor policy must be attached to the frontend backend service when security_policy_id is provided."
  }
}

run "no_cloud_armor_by_default" {
  command = plan

  assert {
    condition     = google_compute_backend_service.this.security_policy == null
    error_message = "security_policy must be null when security_policy_id is not provided."
  }
}
