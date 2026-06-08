# ============================================
# VPC and Networking
# ============================================

# VPC Network
module "vpc" {
  source = "../modules/foundation/vpc"

  name   = "${var.name}-vpc"
  region = var.region
}

# Cloud Firewall
module "firewall" {
  source = "../modules/foundation/cloud_firewall"

  name          = "${var.name}-firewall"
  network_name  = module.vpc.network_name
  allowed_ports = ["443", "8080"]
  source_ranges = ["10.0.0.0/8"]
}
