# A GKE node pool with its own lifecycle. Replacing or resizing it never touches
# the control plane, and a second pool (e.g. spot, or a different machine shape)
# is another instance of this module.

resource "google_container_node_pool" "this" {
  name     = var.name
  project  = var.project_id
  cluster  = var.cluster_id
  location = var.location

  # Empty → GKE uses the cluster's zones. A zonal cluster has one; a regional
  # one has three, so min/max below are per zone.
  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  autoscaling {
    min_node_count  = var.min_node_count
    max_node_count  = var.max_node_count
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Surge one node at a time and never take capacity away during an upgrade.
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    image_type   = "COS_CONTAINERD"
    spot         = var.spot

    # A dedicated, minimal node identity. Without it nodes run as the Compute
    # Engine default SA, which holds roles/editor on the project. The broad scope
    # is the GKE-recommended setting: IAM on the SA, not scopes, decides access.
    service_account = var.service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # GKE_METADATA serves pods the metadata server for Workload Identity and
    # hides the node's own credentials from them.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = var.labels
    tags   = var.network_tags

    dynamic "taint" {
      for_each = var.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  lifecycle {
    # The autoscaler owns the live node count.
    ignore_changes = [initial_node_count]
  }
}
