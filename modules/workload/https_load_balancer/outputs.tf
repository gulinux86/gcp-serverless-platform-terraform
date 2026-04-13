output "load_balancer_ip" {
  description = "Global IP address of the HTTPS load balancer"
  value       = google_compute_global_address.this.address
}

output "ssl_certificate_name" {
  description = "Name of the managed SSL certificate (null when domain not set)"
  value       = var.domain != null ? google_compute_managed_ssl_certificate.this[0].name : null
}

output "api_backend_service_self_link" {
  description = "Self-link of the API backend service (null when api_cloud_run_service_name is not set)"
  value       = var.api_cloud_run_service_name != null ? google_compute_backend_service.api[0].self_link : null
}
