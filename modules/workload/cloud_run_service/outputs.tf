output "service_url" {
  description = "Public URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "name" {
  description = "Cloud Run service name"
  value       = var.name
}

output "decommission_signal" {
  description = "Signal indicating that the service and its cooldown are finished"
  value       = time_sleep.wait_for_ip_release.id
}
