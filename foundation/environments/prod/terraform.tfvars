# Foundation layer — PROD. project_id via TF_VAR_project_id (secret PROD_PROJECT_ID).
name        = "app-prod"
environment = "prod"
region      = "us-central1"

# --- Network ------------------------------------------------------------------
node_subnet_cidr = "10.0.0.0/22"
pods_cidr        = "10.4.0.0/16"
services_cidr    = "10.8.0.0/20"

# --- Cluster ------------------------------------------------------------------
# Regional: control plane replicated across three zones, survives a zone loss.
cluster_location    = "us-central1"
release_channel     = "STABLE"
deletion_protection = true

# --- Nodes --------------------------------------------------------------------
# On-demand. min/max are per zone: 1..3 in each of the three zones.
node_machine_type = "e2-standard-4"
node_spot         = false
node_min_count    = 1
node_max_count    = 3
