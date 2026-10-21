output "firewall_rule_name" {
  description = "Name of the internal allow firewall rule"
  value       = google_compute_firewall.allow_internal.name
}

