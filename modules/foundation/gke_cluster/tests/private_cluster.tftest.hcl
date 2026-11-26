# private_cluster.tftest.hcl
#
# Trade-off context:
#   "Private cluster" is three settings, not one, and dropping any of them leaves
#   something reachable from the internet that the architecture says is not:
#     - private nodes (no external IP on any node),
#     - private IP endpoint for the control plane,
#     - no GCP-public CIDRs on the authorised networks.
#   The DNS endpoint is the deliberate exception: open to external traffic, but
#   authorised per request by IAM rather than by source IP.

mock_provider "google" {}

variables {
  name                = "app-gke"
  project_id          = "my-project"
  location            = "us-central1"
  network_id          = "projects/my-project/global/networks/app-vpc"
  subnet_id           = "projects/my-project/regions/us-central1/subnetworks/app-vpc-private"
  pods_range_name     = "app-vpc-pods"
  services_range_name = "app-vpc-services"
}

run "nodes_and_endpoint_are_private" {
  command = plan

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes == true
    error_message = "Nodes must have no external IP."
  }

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_endpoint == true
    error_message = "The control plane's IP endpoint must be internal. External access goes through the IAM-authorised DNS endpoint."
  }

  assert {
    condition     = google_container_cluster.this.master_authorized_networks_config[0].gcp_public_cidrs_access_enabled == false
    error_message = "GCP public CIDRs must not be authorised: that range includes every Compute Engine VM of every customer."
  }
}

run "dns_endpoint_is_the_external_path" {
  command = plan

  assert {
    condition     = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].allow_external_traffic == true
    error_message = "CI reaches the control plane through the DNS endpoint; without external traffic on it the workload layer cannot install Argo CD."
  }
}

run "workload_identity_and_vpc_native" {
  command = plan

  assert {
    condition     = google_container_cluster.this.workload_identity_config[0].workload_pool == "my-project.svc.id.goog"
    error_message = "Workload Identity must be enabled on the project's pool, or pods fall back to the node service account."
  }

  assert {
    condition     = google_container_cluster.this.networking_mode == "VPC_NATIVE"
    error_message = "The cluster must be VPC-native: private clusters require it, and so do container-native NEGs for the Gateway."
  }

  assert {
    condition     = google_container_cluster.this.ip_allocation_policy[0].cluster_secondary_range_name == "app-vpc-pods"
    error_message = "Pod IPs must come from the subnet's named pod range."
  }
}

run "hardening" {
  command = plan

  assert {
    condition     = google_container_cluster.this.remove_default_node_pool == true
    error_message = "The default node pool must be removed; node pools are managed by the gke_node_pool module."
  }

  assert {
    condition     = google_container_cluster.this.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Dataplane V2 is what enforces NetworkPolicy in this cluster."
  }

  assert {
    condition     = google_container_cluster.this.master_auth[0].client_certificate_config[0].issue_client_certificate == false
    error_message = "Client certificates are a static, non-revocable credential. Authentication is IAM only."
  }

  assert {
    condition     = google_container_cluster.this.enable_shielded_nodes == true
    error_message = "Shielded nodes must be on."
  }

  assert {
    condition     = google_container_cluster.this.gateway_api_config[0].channel == "CHANNEL_STANDARD"
    error_message = "The Gateway API must be enabled: the platform's load balancer is declared as a Gateway in Git."
  }
}

run "deletion_protection_defaults_on" {
  command = plan

  assert {
    condition     = google_container_cluster.this.deletion_protection == true
    error_message = "deletion_protection must default to true; environments that are rebuilt often opt out explicitly."
  }
}
