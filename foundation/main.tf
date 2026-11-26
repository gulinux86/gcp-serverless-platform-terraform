locals {
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    layer       = "foundation"
  }
}

# ============================================
# VPC and Networking
# ============================================

# VPC-native network: node subnet with secondary ranges for pods and Services,
# plus the PSA peering Cloud SQL uses.
module "vpc" {
  source = "../modules/foundation/vpc"

  name                = "${var.name}-vpc"
  region              = var.region
  private_subnet_cidr = var.node_subnet_cidr
  pods_cidr           = var.pods_cidr
  services_cidr       = var.services_cidr
}

# Internal traffic only. GKE adds the rules it needs itself (control plane →
# nodes, LB health checks for the Gateway), and removes them with the cluster.
module "firewall" {
  source = "../modules/foundation/cloud_firewall"

  name          = "${var.name}-firewall"
  network_name  = module.vpc.network_name
  allowed_ports = ["443", "8080"]
  source_ranges = ["10.0.0.0/8"]
}

# The private nodes' only route to the internet (image pulls, Argo CD → GitHub).
module "nat" {
  source = "../modules/foundation/cloud_nat"

  name       = var.name
  region     = var.region
  network_id = module.vpc.network_id
  subnet_id  = module.vpc.private_subnet_id
}

# ============================================
# GKE Standard — private cluster
# ============================================

# Node identity: the minimum GKE documents for a node (logs, metrics, image
# pulls). Workloads never use it — they get their own SA via Workload Identity.
module "node_sa" {
  source = "../modules/workload/iam_service_account"

  account_id   = "${var.name}-gke-nodes"
  display_name = "GKE nodes (${var.environment})"
  project_id   = var.project_id

  iam_roles = {
    "roles/container.defaultNodeServiceAccount" = "roles/container.defaultNodeServiceAccount"
    "roles/artifactregistry.reader"             = "roles/artifactregistry.reader"
  }
}

module "gke" {
  source = "../modules/foundation/gke_cluster"

  name                       = "${var.name}-gke"
  project_id                 = var.project_id
  location                   = var.cluster_location
  network_id                 = module.vpc.network_id
  subnet_id                  = module.vpc.private_subnet_id
  pods_range_name            = module.vpc.pods_range_name
  services_range_name        = module.vpc.services_range_name
  release_channel            = var.release_channel
  master_authorized_networks = var.master_authorized_networks
  deletion_protection        = var.deletion_protection
  labels                     = local.labels

  # NAT must exist before nodes boot, or their first image pulls fail.
  depends_on = [module.nat]
}

module "node_pool" {
  source = "../modules/foundation/gke_node_pool"

  name                  = "${var.name}-default"
  project_id            = var.project_id
  cluster_id            = module.gke.id
  location              = module.gke.location
  machine_type          = var.node_machine_type
  spot                  = var.node_spot
  min_node_count        = var.node_min_count
  max_node_count        = var.node_max_count
  service_account_email = module.node_sa.email
  labels                = { environment = var.environment }
}
