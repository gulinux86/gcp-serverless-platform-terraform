resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

# Holds the workload decommission signal so the subnetwork can depend on it as a resource.
# When var.serverless_decommission_signal is provided, this resource is only considered
# destroyed after the workload's 90s IP-release cooldown has completed.
resource "terraform_data" "serverless_signal" {
  count = var.serverless_decommission_signal != null ? 1 : 0
  input = var.serverless_decommission_signal
}

resource "google_compute_subnetwork" "private" {
  name                     = "${var.name}-private"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  log_config {
    aggregation_interval = var.log_aggregation_interval
    flow_sampling        = var.log_flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Destruction order:
  # 1. serverless_signal (workload 90s cooldown) must be destroyed first
  # 2. Then this subnet can be deleted
  # 3. decommissioning_buffer then waits before PSA connection is removed
  depends_on = [terraform_data.serverless_signal, time_sleep.decommissioning_buffer]
}

resource "google_compute_subnetwork" "private_2" {
  name                     = "${var.name}-private-2"
  ip_cidr_range            = var.secondary_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  log_config {
    aggregation_interval = var.log_aggregation_interval
    flow_sampling        = var.log_flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }

  depends_on = [terraform_data.serverless_signal, time_sleep.decommissioning_buffer]
}

# Reserved IP range for PSA (Private Service Access)
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.name}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.this.id
}

# Service Networking Connection for PSA
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  # ABANDON avoids destroy-time errors: GCP cleans up the peering when the
  # network is deleted. Without this, the API call often fails or times out.
  deletion_policy = "ABANDON"
}

# 10-minute buffer between subnet deletion and PSA connection deletion.
# Allows GCP to release internal PSA locks after the subnet is gone.
# Creation: IP Range -> Peering -> Buffer -> Subnet
# Destruction: Subnet -> Buffer (wait 10m) -> Peering -> IP Range
resource "time_sleep" "decommissioning_buffer" {
  destroy_duration = "600s"

  depends_on = [google_service_networking_connection.default]
}
