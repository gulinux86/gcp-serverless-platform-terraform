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

run "private_subnets_have_google_access" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.private_ip_google_access == true
    error_message = "Primary private subnet must have Private Google Access enabled. Cloud Run Direct VPC Egress instances need it to reach Google APIs (Secret Manager, Artifact Registry) without a public IP."
  }

  assert {
    condition     = google_compute_subnetwork.private_2.private_ip_google_access == true
    error_message = "Secondary private subnet must have Private Google Access enabled."
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

run "subnets_do_not_overlap" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.private.ip_cidr_range != google_compute_subnetwork.private_2.ip_cidr_range
    error_message = "The two private subnets must occupy distinct ranges. Cloud Run attaches Direct VPC Egress interfaces to the primary subnet, and an overlapping secondary range would make routing ambiguous."
  }
}
