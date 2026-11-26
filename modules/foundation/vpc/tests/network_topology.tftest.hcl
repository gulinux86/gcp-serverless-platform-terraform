# network_topology.tftest.hcl
#
# Trade-off context:
#   The VPC module encodes several non-obvious GCP behaviors that look wrong
#   at first glance but are intentional:
#     - deletion_policy = "ABANDON" on the PSA connection: GCP recommends ABANDON
#       because the API call to delete the peering often fails with 409 errors.
#     - decommissioning_buffer (10 min time_sleep): GCP holds PSA locks for several
#       minutes after subnet deletion. Without the buffer, terraform destroy races
#       against internal GCP cleanup and fails with "resource in use" errors.
#     - the node subnet carries two secondary ranges: a private GKE cluster is
#       VPC-native, and without them the cluster cannot be created at all.
#   These tests prevent well-intentioned "cleanup" of these patterns by future
#   contributors who don't know why they exist.

mock_provider "google" {}
mock_provider "time" {}

variables {
  name = "app"
}

run "vpc_does_not_auto_create_subnets" {
  command = plan

  assert {
    condition     = google_compute_network.this.auto_create_subnetworks == false
    error_message = "VPC must not auto-create subnets. Auto-created subnets use predefined CIDRs that overlap with PSA ranges and cannot be individually configured for flow logs."
  }
}

run "node_subnet_has_google_access" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.private_ip_google_access == true
    error_message = "The node subnet must have Private Google Access enabled. Private GKE nodes have no public IP and reach Artifact Registry, Secret Manager and the GKE APIs through it."
  }
}

run "node_subnet_is_vpc_native" {
  command = plan

  assert {
    condition     = length(google_compute_subnetwork.private.secondary_ip_range) == 2
    error_message = "The node subnet must carry exactly two secondary ranges (pods, services). A VPC-native GKE cluster references them by name."
  }

  assert {
    condition = alltrue([
      for r in google_compute_subnetwork.private.secondary_ip_range :
      r.ip_cidr_range != google_compute_subnetwork.private.ip_cidr_range
    ])
    error_message = "Secondary ranges must not reuse the node range."
  }

  assert {
    condition     = google_compute_subnetwork.private.secondary_ip_range[0].ip_cidr_range != google_compute_subnetwork.private.secondary_ip_range[1].ip_cidr_range
    error_message = "Pod and Service ranges must be distinct."
  }
}

run "flow_logs_enabled_on_subnets" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Flow logs must include all metadata for security analysis and incident response."
  }
}

run "psa_range_is_internal_vpc_peering" {
  command = plan

  assert {
    condition     = google_compute_global_address.private_ip_alloc.purpose == "VPC_PEERING"
    error_message = "PSA IP range must be reserved with purpose=VPC_PEERING. Any other purpose prevents Cloud SQL from using it for Private Service Access."
  }

  assert {
    condition     = google_compute_global_address.private_ip_alloc.address_type == "INTERNAL"
    error_message = "PSA IP range must be INTERNAL. An EXTERNAL allocation would make the Cloud SQL private range internet-routable."
  }
}

run "psa_connection_uses_abandon_policy" {
  command = plan

  assert {
    condition     = google_service_networking_connection.default.deletion_policy == "ABANDON"
    error_message = "PSA connection must use deletion_policy=ABANDON. The GCP servicenetworking API frequently returns 409 errors when Terraform attempts to delete the peering explicitly — ABANDON lets GCP clean it up when the network is deleted."
  }
}
