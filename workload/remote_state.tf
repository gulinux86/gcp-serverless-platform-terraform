# Cross-layer handshake: the workload layer reads the foundation layer's outputs
# from its remote state instead of receiving them as inputs from a root module.
# This makes "foundation applied before workload" a hard dependency, enforced in
# CI by the deploy ordering and the terraform-plan foundation-state guard.
data "terraform_remote_state" "foundation" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "${var.environment}/foundation"
  }
}
