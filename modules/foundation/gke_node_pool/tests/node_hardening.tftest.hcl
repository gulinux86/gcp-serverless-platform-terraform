# node_hardening.tftest.hcl
#
# Trade-off context:
#   Node-level settings decide what a compromised pod can reach. GKE_METADATA
#   hides the node's credentials, a dedicated SA keeps those credentials minimal,
#   and shielded boot makes node tampering detectable. Each of these is one line
#   that is easy to drop when copying a node pool from a tutorial.

mock_provider "google" {}

variables {
  name                  = "default"
  project_id            = "my-project"
  cluster_id            = "projects/my-project/locations/us-central1/clusters/app-gke"
  location              = "us-central1"
  service_account_email = "gke-nodes@my-project.iam.gserviceaccount.com"
}

run "workload_identity_metadata" {
  command = plan

  assert {
    condition     = google_container_node_pool.this.node_config[0].workload_metadata_config[0].mode == "GKE_METADATA"
    error_message = "Nodes must serve the GKE metadata server; anything else exposes the node SA's token to every pod."
  }

  assert {
    condition     = google_container_node_pool.this.node_config[0].metadata["disable-legacy-endpoints"] == "true"
    error_message = "Legacy metadata endpoints must be disabled."
  }
}

run "dedicated_service_account" {
  command = plan

  assert {
    condition     = google_container_node_pool.this.node_config[0].service_account == var.service_account_email
    error_message = "Nodes must run as the dedicated node SA."
  }
}

run "default_compute_sa_is_rejected" {
  command = plan

  variables {
    service_account_email = "123456789-compute@developer.gserviceaccount.com"
  }

  expect_failures = [var.service_account_email]
}

run "shielded_and_self_healing" {
  command = plan

  assert {
    condition     = google_container_node_pool.this.node_config[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "Secure boot must be on."
  }

  assert {
    condition     = google_container_node_pool.this.management[0].auto_repair == true && google_container_node_pool.this.management[0].auto_upgrade == true
    error_message = "Auto-repair and auto-upgrade must be on; the release channel relies on them."
  }

  assert {
    condition     = google_container_node_pool.this.upgrade_settings[0].max_unavailable == 0
    error_message = "Upgrades must surge, never remove capacity first."
  }
}
