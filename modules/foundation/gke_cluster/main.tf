# GKE Standard, private, VPC-native.
#
# Private on both sides:
#   - nodes: no external IP (enable_private_nodes); egress goes through Cloud NAT.
#   - control plane: the IP endpoint is internal only (enable_private_endpoint).
#
# Access to the API server from outside the VPC goes through the DNS-based
# endpoint instead (control_plane_endpoints_config). It is authorised by IAM —
# every request carries a Google identity that must hold container.clusters.connect
# — rather than by a source-IP allowlist. That is what lets a GitHub-hosted runner,
# whose IP is unpredictable, install Argo CD without either opening the IP
# endpoint to 0.0.0.0/0 or running a bastion (ARCHITECTURE.md §Control plane access).

resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # Node pools live in their own module so they can be replaced or upgraded
  # without touching the control plane. GKE insists on creating a default pool;
  # it is removed as soon as the cluster exists.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.release_channel
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
    ip_endpoints_config {
      enabled = true
    }
  }

  # Governs the (internal) IP endpoint. An empty list still matters: with
  # gcp_public_cidrs_access_enabled off, only addresses inside the VPC reach it.
  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled      = false
    private_endpoint_enforcement_enabled = true

    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Pods assume Google service accounts through their Kubernetes SA, with no
  # exported key — the replacement for Cloud Run's per-service identity.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Dataplane V2 (eBPF/Cilium). Enforces NetworkPolicy natively, so the legacy
  # `network_policy` block (Calico) is deliberately absent — setting both is
  # rejected by the API.
  datapath_provider = "ADVANCED_DATAPATH"

  # The GKE Gateway controller, run by Google in the control plane. A Gateway
  # declared in Git becomes a Global External Application LB; Cloud Armor is
  # attached to it from Git through a GCPBackendPolicy.
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  addons_config {
    # Required by the Gateway controller and container-native NEGs.
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  enable_shielded_nodes       = true
  enable_intranode_visibility = true

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  binary_authorization {
    evaluation_mode = var.binary_authorization_mode
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  resource_labels = var.labels

  deletion_protection = var.deletion_protection

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
