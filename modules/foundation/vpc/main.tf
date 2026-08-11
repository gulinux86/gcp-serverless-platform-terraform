resource "google_compute_network" "this" {
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
}

# Dedicated /28 subnet for the Serverless VPC Access Connector.
#
# Why an explicit subnet instead of the connector's `ip_cidr_range` shortcut:
# with ip_cidr_range, GCP provisions a managed subnet that never appears in
# `gcloud compute networks subnets list` — which means private_ip_google_access
# cannot be set on it. Connector instances have no external IP and this VPC has
# no Cloud NAT, so without Private Google Access they cannot reach Google APIs
# to report health, and creation fails with "connector failed to get healthy".
# Owning the subnet also lets firewall rules target the range explicitly.
resource "google_compute_subnetwork" "connector" {
  name                     = "${var.name}-connector"
  ip_cidr_range            = var.connector_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  purpose                  = "PRIVATE"
  private_ip_google_access = true

  # No flow logs here: this /28 carries only connector-internal traffic, and the
  # application-visible flows are already captured on the private subnets.
}

# Serverless VPC Access Connector — the egress path Cloud Run uses to reach the
# VPC. Replaces Direct VPC Egress: the connector is a managed resource with its
# own dedicated /28, so no per-service IP reservations linger in the application
# subnets on destroy. This removes the need for the workload IP-release cooldowns
# (time_sleep guards) and the serverless_decommission_signal handshake.
#
# `subnet` and `ip_cidr_range`/`network` are mutually exclusive — attaching to
# the subnet above is what gives the connector Private Google Access.
resource "google_vpc_access_connector" "this" {
  name          = "${var.name}-connector"
  region        = var.region
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances
  machine_type  = var.connector_machine_type

  subnet {
    name = google_compute_subnetwork.connector.name
  }
}

# Connector instances are tagged `vpc-connector` (and
# `vpc-connector-<region>-<name>`) by Serverless VPC Access. The two rules below
# open the probe paths the connector needs to report healthy. Both are scoped to
# Google-owned source ranges AND to the connector tag, so they grant nothing to
# application workloads.

# Control-plane requests from Google infrastructure to the connector.
resource "google_compute_firewall" "connector_requests" {
  name        = "${var.name}-connector-requests"
  network     = google_compute_network.this.name
  direction   = "INGRESS"
  priority    = 1000
  target_tags = ["vpc-connector"]

  source_ranges = [
    "35.199.224.0/19",   # Serverless VPC Access control plane
    "107.178.230.64/26", # Google infrastructure
  ]

  allow {
    protocol = "tcp"
    ports    = ["667"]
  }

  allow {
    protocol = "udp"
    ports    = ["665-666"]
  }

  allow {
    protocol = "icmp"
  }

  description = "Serverless VPC Access control-plane requests to connector instances"
}

# Health checks. Without these the instances start but never pass the health
# check, and the create call fails after ~5 minutes with a generic internal error.
resource "google_compute_firewall" "connector_health_checks" {
  name        = "${var.name}-connector-health-checks"
  network     = google_compute_network.this.name
  direction   = "INGRESS"
  priority    = 1000
  target_tags = ["vpc-connector"]

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "108.170.220.0/23",
  ]

  allow {
    protocol = "tcp"
    ports    = ["667"]
  }

  description = "Google health-check probes to VPC Access Connector instances"
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
