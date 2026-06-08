# ingress_security.tftest.hcl
#
# Trade-off context:
#   Cloud Run has two independent access control layers:
#     1. ingress — which NETWORK paths can reach the service (VPC, LB, public)
#     2. IAM  — which IDENTITIES can invoke the service (allUsers vs authenticated)
#   Both must be tested independently. A service with ingress=INTERNAL_ONLY but
#   make_public=true is correctly locked at the network layer. A service with
#   ingress=ALL and make_public=false is reachable from the internet but requires
#   auth — a different risk profile. These tests enforce the expected defaults.

mock_provider "google" {}

variables {
  name  = "test-service"
  image = "gcr.io/test-project/app:latest"
}

run "default_ingress_is_not_all_traffic" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.ingress != "INGRESS_TRAFFIC_ALL"
    error_message = "Default ingress must never be INGRESS_TRAFFIC_ALL. Services must not be directly reachable from the internet — traffic must flow through the load balancer."
  }
}

run "default_ingress_is_internal_only" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.ingress == "INGRESS_TRAFFIC_INTERNAL_ONLY"
    error_message = "Default ingress must be INGRESS_TRAFFIC_INTERNAL_ONLY. Production services should explicitly opt in to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

run "validation_rejects_invalid_ingress_value" {
  command = plan

  variables {
    ingress = "DIRECT_INTERNET_EXPOSURE"
  }

  # Trade-off: expect_failures validates that the variable validation block works.
  # Without this test, someone could remove the validation block and the module
  # would silently accept any string — GCP would reject it at apply time, not plan time.
  expect_failures = [var.ingress]
}

run "no_public_iam_binding_when_private" {
  command = plan

  variables {
    make_public = false
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.noauth) == 0
    error_message = "No allUsers IAM binding must be created when make_public = false."
  }
}

run "public_iam_binding_when_explicitly_enabled" {
  command = plan

  variables {
    make_public = true
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.noauth) == 1
    error_message = "allUsers IAM binding must be created when make_public = true."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.noauth[0].role == "roles/run.invoker"
    error_message = "Public IAM binding must grant exactly roles/run.invoker — no broader role."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.noauth[0].member == "allUsers"
    error_message = "Public IAM binding member must be 'allUsers'."
  }
}
