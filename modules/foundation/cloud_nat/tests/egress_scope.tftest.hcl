# egress_scope.tftest.hcl
#
# Trade-off context:
#   NAT is the only internet path a private cluster has. Scoping it to the node
#   subnet (LIST_OF_SUBNETWORKS) instead of ALL_SUBNETWORKS_ALL_IP_RANGES keeps a
#   future subnet from silently inheriting outbound internet access.

mock_provider "google" {}

variables {
  name       = "app"
  region     = "us-central1"
  network_id = "projects/p/global/networks/app-vpc"
  subnet_id  = "projects/p/regions/us-central1/subnetworks/app-vpc-private"
}

run "nat_is_scoped_to_the_node_subnet" {
  command = plan

  assert {
    condition     = google_compute_router_nat.this.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
    error_message = "NAT must list its subnets explicitly. ALL_SUBNETWORKS_* would give every future subnet an internet egress path."
  }

  assert {
    condition     = one(google_compute_router_nat.this.subnetwork).name == var.subnet_id
    error_message = "NAT must cover the node subnet."
  }

  assert {
    condition     = contains(one(google_compute_router_nat.this.subnetwork).source_ip_ranges_to_nat, "ALL_IP_RANGES")
    error_message = "NAT must cover the secondary (pod) ranges too, or pods cannot reach the internet even though their node can."
  }
}

run "nat_logs_errors" {
  command = plan

  assert {
    condition     = google_compute_router_nat.this.log_config[0].enable == true
    error_message = "NAT logging must be on: port exhaustion is otherwise invisible."
  }
}
