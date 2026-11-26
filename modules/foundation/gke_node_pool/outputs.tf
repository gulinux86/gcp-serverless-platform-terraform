output "name" {
  description = "Node pool name"
  value       = google_container_node_pool.this.name
}

output "id" {
  description = "Node pool ID"
  value       = google_container_node_pool.this.id
}
