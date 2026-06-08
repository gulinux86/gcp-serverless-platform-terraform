resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

# Serverless VPC Access Connector — the egress path Cloud Run uses to reach the
# VPC. Replaces Direct VPC Egress: the connector is a managed resource with its
# own dedicated /28, so no per-service IP reservations linger in the application
# subnets on destroy. This removes the need for the workload IP-release cooldowns
# (time_sleep guards) and the serverless_decommission_signal handshake.
resource "google_vpc_access_connector" "this" {
  name          = "${var.name}-connector"
  region        = var.region
  network       = google_compute_network.this.name
  ip_cidr_range = var.connector_cidr
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances
  machine_type  = var.connector_machine_type
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
  # 1. This subnet is deleted (Cloud Run no longer reserves IPs here — egress
  #    goes through the VPC Access Connector's own /28).
  # 2. decommissioning_buffer then waits before the PSA connection is removed.
  depends_on = [time_sleep.decommissioning_buffer]
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

  depends_on = [time_sleep.decommissioning_buffer]
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
