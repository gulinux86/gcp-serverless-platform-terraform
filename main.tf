# ============================================
# Infrastructure Orchestration
# ============================================

# Foundation Layer (Networking)
module "foundation" {
  source = "./foundation"

  project_id = var.project_id
  name       = var.name
  region     = var.region

  # NOTE: serverless_decommission_signal is intentionally not wired here.
  # Passing module.workload.serverless_decommission_signal would create a
  # dependency cycle (workload → foundation → workload). The destruction
  # ordering is already enforced by module.workload's depends_on below.
}

# Workload Layer (Compute and Resources)
module "workload" {
  source = "./workload"

  project_id     = var.project_id
  name           = var.name
  region         = var.region
  db_password    = var.db_password
  api_secret_key = var.api_secret_key
  domain_name    = var.domain_name

  # Link Foundation Outputs to Workload Inputs
  vpc_network_id    = module.foundation.vpc_network_id
  private_subnet_id = module.foundation.private_subnet_id
  vpc_peering_id    = module.foundation.psa_connection_id

  # Ensure Workload is created AFTER Foundation and destroyed BEFORE it.
  depends_on = [module.foundation]
}
