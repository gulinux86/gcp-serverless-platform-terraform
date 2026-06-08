# least_privilege.tftest.hcl
#
# Trade-off context:
#   These tests validate that security defaults are encoded in code, not just
#   in documentation. The key insight: "least privilege" is meaningless if the
#   Terraform module defaults can silently grant broad permissions. Each test
#   here is a regression guard against a future change that relaxes a safe default.

mock_provider "google" {}

variables {
  account_id = "test-sa"
  project_id = "test-project"
}

run "no_key_created_by_default" {
  command = plan

  assert {
    condition     = length(google_service_account_key.this) == 0
    error_message = "Service account keys must NOT be created by default. Keys are long-lived credentials that bypass IAM Conditions and cannot be audited like short-lived tokens."
  }
}

run "key_only_created_on_explicit_opt_in" {
  command = plan

  variables {
    create_key = true
  }

  assert {
    condition     = length(google_service_account_key.this) == 1
    error_message = "Exactly one key must be created when create_key = true."
  }
}

run "no_project_roles_by_default" {
  command = plan

  assert {
    condition     = length(google_project_iam_member.this) == 0
    error_message = "No project-level IAM roles must be assigned by default. Permissions require explicit declaration — least privilege must be an opt-in, not an opt-out."
  }
}

run "one_binding_created_per_role" {
  command = plan

  variables {
    iam_roles = {
      "invoker" = "roles/run.invoker"
      "viewer"  = "roles/storage.objectViewer"
    }
  }

  assert {
    condition     = length(google_project_iam_member.this) == 2
    error_message = "Must create exactly one IAM binding per role entry. A mismatch suggests the for_each logic is broken."
  }
}

run "no_sa_iam_bindings_by_default" {
  command = plan

  assert {
    condition     = length(google_service_account_iam_member.this) == 0
    error_message = "No service account IAM bindings must exist by default. Workload Identity or impersonation grants require explicit opt-in."
  }
}
