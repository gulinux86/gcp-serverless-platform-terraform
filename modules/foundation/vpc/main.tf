resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

# The GKE node subnet. VPC-native (alias IP): nodes take their address from the
# primary range, pods and Services from the two secondary ranges below. Pods are
# therefore first-class VPC addresses — Cloud SQL over PSA, NetworkPolicy and the
# Gateway's container-native NEGs all see the pod IP, with no extra NAT hop.
#
# Sizing: a /16 pod range gives 256 nodes at the default 110 pods/node (/24 per
# node). The Service range only has to hold ClusterIPs.
resource "google_compute_subnetwork" "private" {
  name                     = "${var.name}-private"
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${var.name}-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.name}-services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = var.log_aggregation_interval
    flow_sampling        = var.log_flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }

  # Destruction order:
  # 1. This subnet is deleted (only possible once the cluster, its nodes and any
  #    NEGs the Gateway controller created are gone — see terraform-destroy.yml).
  # 2. decommissioning_buffer then waits before the PSA connection is removed.
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
