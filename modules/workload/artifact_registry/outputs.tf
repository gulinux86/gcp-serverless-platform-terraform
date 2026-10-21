output "repository_id" {
  description = "Repository ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Full repository name"
  value       = google_artifact_registry_repository.this.name
}

output "repository_url" {
  description = "Registry host path for pushing/pulling images (<location>-docker.pkg.dev/<project>/<repository_id>). Only meaningful for format = DOCKER."
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${google_artifact_registry_repository.this.project}/${google_artifact_registry_repository.this.repository_id}"
}
