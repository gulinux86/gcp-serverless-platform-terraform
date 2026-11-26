# Foundation layer — HML. project_id is injected via TF_VAR_project_id
# (GitHub secret HML_PROJECT_ID in CI; export locally). Not committed here.
name        = "app-hml"
environment = "hml"
region      = "us-central1"

# --- Network ------------------------------------------------------------------
node_subnet_cidr = "10.0.0.0/22"
pods_cidr        = "10.4.0.0/16"
services_cidr    = "10.8.0.0/20"

# --- Cluster ------------------------------------------------------------------
# Zonal: one control-plane replica, covered by the GKE free tier. hml trades the
# regional control plane's availability for cost.
cluster_location    = "us-central1-a"
release_channel     = "REGULAR"
deletion_protection = false

# --- Nodes --------------------------------------------------------------------
# On-demand, like prod: no preemptions disrupting Argo CD syncs or tests.
node_machine_type = "e2-standard-2"
node_spot         = false
node_min_count    = 1
node_max_count    = 3
