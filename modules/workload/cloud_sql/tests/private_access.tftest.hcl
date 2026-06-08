# private_access.tftest.hcl
#
# Trade-off context:
#   Cloud SQL with a public IP is a serious exposure: the instance becomes
#   reachable from anywhere on the internet, even with authorized_networks
#   configured. The correct pattern is private IP only, routed through PSA.
#   The dangerous thing about Cloud SQL misconfigurations is that they don't
#   cause Terraform errors — they just provision a less secure instance.
#   These tests treat the private-only constraint as a non-negotiable invariant,
#   not a configuration option.

mock_provider "google" {}
mock_provider "time" {}

variables {
  name        = "test-db"
  db_password = "test-password-not-real"
}

run "database_never_has_public_ip" {
  command = plan

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "Cloud SQL must NEVER have a public IPv4 address. ipv4_enabled is hardcoded to false and must not be changed. A public IP exposes the instance to the internet regardless of authorized_networks settings."
  }
}

run "private_network_always_set" {
  command = plan

  variables {
    vpc_network_id = "projects/test-project/global/networks/app-vpc"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].private_network != null
    error_message = "Cloud SQL must always be connected to a VPC for private IP access."
  }
}

run "automated_backups_enabled_by_default" {
  command = plan

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled == true
    error_message = "Automated backups must be enabled by default. Disabling them requires an explicit opt-out that acknowledges the data loss risk."
  }
}

run "deletion_protection_enabled_by_default" {
  command = plan

  assert {
    condition     = google_sql_database_instance.this.deletion_protection == true
    error_message = "Deletion protection must be enabled by default. A terraform destroy on a production database without this guard is unrecoverable."
  }
}

run "ha_regional_by_default" {
  command = plan

  assert {
    condition     = google_sql_database_instance.this.settings[0].availability_type == "REGIONAL"
    error_message = "Default availability_type must be REGIONAL (high availability). ZONAL means a single zone failure takes down the database — acceptable only for non-production environments."
  }
}

run "validation_rejects_invalid_availability_type" {
  command = plan

  variables {
    availability_type = "MULTI_REGION"
  }

  expect_failures = [var.availability_type]
}
