# deny_by_default.tftest.hcl
#
# Trade-off context:
#   The deny_external rule (create_deny_rule = false by default) is an explicit
#   design decision: forcing callers to opt in to deny-all rather than having
#   the module silently create a broad deny rule that might block legitimate
#   traffic in unexpected environments. The allow_internal rule, however, is
#   always created — it defines the minimum viable internal connectivity.
#
#   This is a real trade-off: defaulting create_deny_rule to false means a
#   misconfigured deployment has no explicit deny layer, relying on VPC ingress
#   defaults. The counter-argument: Cloud Run with INGRESS_TRAFFIC_INTERNAL_ONLY
#   and a private-only Cloud SQL already enforce the security perimeter at a
#   higher layer than firewall rules.

mock_provider "google" {}

variables {
  name         = "test-fw"
  network_name = "app-vpc"
}

run "allow_internal_rule_always_created" {
  command = plan

  assert {
    condition     = google_compute_firewall.allow_internal.network == "app-vpc"
    error_message = "Internal allow rule must always be created and attached to the configured network."
  }

  assert {
    condition     = contains(one(google_compute_firewall.allow_internal.allow).ports, "443")
    error_message = "Allow rule must include port 443 (HTTPS) by default."
  }

  assert {
    condition     = contains(one(google_compute_firewall.allow_internal.allow).ports, "80")
    error_message = "Allow rule must include port 80 (HTTP) by default."
  }
}

run "deny_rule_not_created_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_firewall.deny_external) == 0
    error_message = "Deny-all rule must NOT be created by default. Callers must explicitly set create_deny_rule = true after validating that the broad deny won't break their environment."
  }
}

run "deny_rule_created_when_opted_in" {
  command = plan

  variables {
    create_deny_rule = true
  }

  assert {
    condition     = length(google_compute_firewall.deny_external) == 1
    error_message = "Deny-all rule must be created when create_deny_rule = true."
  }

  assert {
    condition     = google_compute_firewall.deny_external[0].direction == "INGRESS"
    error_message = "Deny rule direction must be INGRESS. An EGRESS deny-all would block outbound Cloud Run traffic to Cloud SQL and Secret Manager."
  }

  assert {
    condition     = contains(one(google_compute_firewall.deny_external[0].deny).protocol == "all" ? ["all"] : [], "all")
    error_message = "Deny rule must block all protocols to enforce explicit deny-by-default posture."
  }
}

run "source_ranges_default_to_rfc1918" {
  command = plan

  assert {
    condition     = contains(google_compute_firewall.allow_internal.source_ranges, "10.0.0.0/8")
    error_message = "Default source range for internal allow rule must be RFC-1918 (10.0.0.0/8). A broader range would allow non-private traffic through the internal rule."
  }
}
