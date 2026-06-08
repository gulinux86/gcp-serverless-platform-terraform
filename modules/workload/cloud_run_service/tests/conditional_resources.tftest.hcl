# conditional_resources.tftest.hcl
#
# Trade-off context:
#   Conditional resources (count/for_each with ternary expressions) are the most
#   common source of silent regressions in Terraform modules. A code reviewer can
#   audit a static resource in seconds; a broken dynamic block is invisible unless
#   the plan is inspected manually. These tests catch the "silent empty plan"
#   problem: a refactor that breaks a conditional produces zero errors but also
#   zero resources — infrastructure disappears without warning.

mock_provider "google" {}

variables {
  name  = "test-service"
  image = "gcr.io/test-project/app:latest"
}

run "no_gcs_volume_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].volumes) == 0
    error_message = "No GCS FUSE volume must be created when gcs_bucket_name is not set. Unexpected volumes in a container are a security and cost risk."
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].containers[0].volume_mounts) == 0
    error_message = "No volume mounts must exist when gcs_bucket_name is not set."
  }
}

run "gcs_volume_and_mount_created_together" {
  command = plan

  variables {
    gcs_bucket_name = "my-assets-bucket"
    mount_path      = "/mnt/assets"
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].volumes) == 1
    error_message = "GCS FUSE volume must be created when gcs_bucket_name is set."
  }

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].containers[0].volume_mounts) == 1
    error_message = "Volume mount must be created alongside the GCS volume. A volume without a mount is inert; a mount without a volume crashes the container at startup."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].containers[0].volume_mounts[0].mount_path == "/mnt/assets"
    error_message = "Volume mount path must match the configured mount_path variable."
  }
}

run "secret_env_vars_injected_into_container" {
  command = plan

  variables {
    secret_env_vars = {
      "DB_PASSWORD" = { secret = "db-password", version = "latest" }
      "API_KEY"     = { secret = "api-key", version = "1" }
    }
  }

  assert {
    condition = length([
      for env in google_cloud_run_v2_service.this.template[0].containers[0].env
      : env if env.name == "DB_PASSWORD" || env.name == "API_KEY"
    ]) == 2
    error_message = "Both secret env vars must be present in the container environment. A missing secret var causes a runtime error, not a startup failure — it surfaces only under load."
  }
}

run "scale_to_zero_by_default" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].scaling[0].min_instance_count == 0
    error_message = "Default min_instance_count must be 0 (scale to zero). Warm instances have a per-second cost — the caller must explicitly opt in to min=1."
  }
}

run "connector_egress_configured_when_set" {
  command = plan

  variables {
    vpc_connector_id = "projects/test/locations/us-central1/connectors/app-vpc-connector"
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].vpc_access[0].connector == "projects/test/locations/us-central1/connectors/app-vpc-connector"
    error_message = "Cloud Run must egress through the VPC Access Connector when one is provided."
  }

  assert {
    condition     = google_cloud_run_v2_service.this.template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    error_message = "Connector egress must route ALL_TRAFFIC through the VPC. Split egress would send private IPs (e.g. Cloud SQL) through the public internet."
  }
}

run "no_vpc_access_without_connector" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_service.this.template[0].vpc_access) == 0
    error_message = "No vpc_access block must be rendered when vpc_connector_id is null — an empty connector reference is invalid at apply time."
  }
}
