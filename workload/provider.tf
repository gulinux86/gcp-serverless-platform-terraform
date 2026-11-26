# The workload layer is an independent root module with its own provider
# configuration.
provider "google" {
  project = var.project_id
  region  = var.region
}

# Short-lived OAuth token of whoever runs Terraform (the CI deployer SA via WIF,
# or your gcloud ADC locally). GKE maps it to Kubernetes RBAC through IAM.
data "google_client_config" "current" {}

# The private cluster is reached through its DNS endpoint, not its IP endpoint
# (which is internal only). The endpoint is authorised by IAM and served with a
# publicly trusted certificate, so there is no cluster CA to pass and no network
# path into the VPC to build — no bastion, no authorized-networks entry for
# GitHub's ever-changing runner IPs.
provider "helm" {
  kubernetes {
    host  = "https://${data.terraform_remote_state.foundation.outputs.cluster_dns_endpoint}"
    token = data.google_client_config.current.access_token
  }
}
