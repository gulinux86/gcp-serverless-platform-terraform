# Egress for a private cluster. The nodes have no external IP, so without NAT
# they cannot pull images from public registries (quay.io, ghcr.io) or let
# Argo CD clone its Git repository. Google APIs do not need this — Private
# Google Access on the subnet covers Artifact Registry and Secret Manager.
resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  region  = var.region
  network = var.network_id
}

resource "google_compute_router_nat" "this" {
  name   = "${var.name}-nat"
  router = google_compute_router.this.name
  region = var.region

  # AUTO_ONLY: Google allocates and releases the egress IPs. Switch to
  # MANUAL_ONLY with reserved addresses if a third party has to allowlist them.
  nat_ip_allocate_option = "AUTO_ONLY"

  # Only the node subnet, all of its ranges (primary for nodes, secondary for
  # pods). Nothing else in the VPC gets a NAT path by accident.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = var.subnet_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = var.log_filter
  }
}
