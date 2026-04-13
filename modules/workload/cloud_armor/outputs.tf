output "security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = google_compute_security_policy.this.name
}

output "security_policy_self_link" {
  description = "Self-link of the Cloud Armor security policy, used to attach to a backend service"
  value       = google_compute_security_policy.this.self_link
}
