resource "google_compute_firewall" "allow_internal" {
  name    = "${var.name}-allow-internal"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = var.allowed_ports
  }

  source_ranges = var.source_ranges
  target_tags   = var.target_tags

  description = "Allow internal traffic"
}

resource "google_compute_firewall" "deny_external" {
  count = var.create_deny_rule ? 1 : 0

  name      = "${var.name}-deny-external"
  network   = var.network_name
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.target_tags

  description = "Deny external traffic (default deny)"
}

