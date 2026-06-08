# The workload layer is an independent root module with its own provider
# configuration (previously inherited from the retired root module).
provider "google" {
  project = var.project_id
  region  = var.region
}
