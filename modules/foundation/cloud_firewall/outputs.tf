output "firewall_rule_name" {
  description = "Nome da regra de firewall"
  value       = google_compute_firewall.allow_internal.name
}

