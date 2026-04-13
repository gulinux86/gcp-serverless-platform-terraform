# Decommissioning buffer: ensures GCP has time to release the PSA link after Cloud SQL is gone.
# By having all SQL resources depend on this timer, the destroy order becomes:
# SQL resources deleted → timer waits 60s → module fully destroyed.
resource "time_sleep" "decommissioning_buffer" {
  destroy_duration = "60s"
}

# Explicit dependency on the PSA connection so Cloud SQL is not created before peering exists,
# and is not recreated when peering changes. Uses terraform_data (built-in, no extra provider).
resource "terraform_data" "wait_for_peering" {
  input = var.vpc_peering_id
}

resource "google_sql_database_instance" "this" {
  name             = var.name
  database_version = var.database_version
  region           = var.region

  settings {
    tier              = var.tier
    availability_type = var.availability_type

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = var.backup_start_time
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network_id
    }

    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }
  }

  deletion_protection = var.deletion_protection

  depends_on = [
    terraform_data.wait_for_peering,
    time_sleep.decommissioning_buffer,
  ]
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  depends_on = [time_sleep.decommissioning_buffer]
}

resource "google_sql_user" "this" {
  name     = var.db_user
  instance = google_sql_database_instance.this.name
  password = var.db_password

  depends_on = [time_sleep.decommissioning_buffer]
}
