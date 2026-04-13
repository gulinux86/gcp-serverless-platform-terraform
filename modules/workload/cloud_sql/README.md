# cloud_sql

PostgreSQL Cloud SQL instance with Private Service Access (PSA) connectivity. Provisions the instance, initial database, and user. Public IP is disabled by default — the instance is reachable only via the private VPC.

## Usage

```hcl
module "database" {
  source = "../modules/workload/cloud_sql"

  name              = "app-db"
  region            = "us-central1"
  database_name     = "appdb"
  db_user           = "appuser"
  db_password       = var.db_password
  tier              = "db-f1-micro"
  availability_type = "REGIONAL"
  public_ip         = false
  vpc_network_id    = module.foundation.vpc_network_id
  vpc_peering_id    = module.foundation.vpc_peering_id
}
```

## Known Behaviors

### PSA dependency ordering (`vpc_peering_id`)

`vpc_peering_id` does not configure the Cloud SQL instance — it exists solely to create an explicit Terraform dependency on the PSA peering connection. Cloud SQL requires the PSA peering to be fully established in GCP before the instance can be created with a private IP. Without this dependency, Terraform may attempt to create the instance before the peering is ready, producing an error like:

```
Error: Error waiting to create DatabaseInstance: Error waiting for Creating
database instance: googleapi: Error 400: Invalid request...
```

Always pass `vpc_peering_id = module.foundation.vpc_peering_id` when using private connectivity.

### Connecting from Cloud Run

Cloud Run services with Direct VPC Egress can reach the instance directly via its private IP. The connection string format is:

```
postgresql://<db_user>@<private-ip>/<database_name>
```

Do not use the Cloud SQL Auth Proxy when Direct VPC Egress is in use — the proxy adds latency and an unnecessary sidecar; direct private IP is preferred.

### `deletion_protection`

Defaults to `true`. Set to `false` only for non-production environments. Terraform will refuse to delete the instance when this is `true` — you must set it to `false` and apply before running `terraform destroy`.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_sql_database.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [terraform_data.wait_for_peering](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_sleep.decommissioning_buffer](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_db_password"></a> [db\_password](#input\_db\_password) | Database password | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Unique name for the Cloud SQL instance. Used as the GCP resource ID and must be unique within the project. | `string` | n/a | yes |
| <a name="input_authorized_network"></a> [authorized\_network](#input\_authorized\_network) | CIDR block permitted to connect over the public IP. Only relevant when `public_ip = true`; ignored for private-only instances. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_availability_type"></a> [availability\_type](#input\_availability\_type) | High availability mode. REGIONAL provisions a standby replica in a different zone with automatic failover. ZONAL is single-zone with no failover. | `string` | `"REGIONAL"` | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Enable automatic backups | `bool` | `true` | no |
| <a name="input_backup_start_time"></a> [backup\_start\_time](#input\_backup\_start\_time) | Backup start time (HH:MM) | `string` | `"03:00"` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the initial database to create inside the Cloud SQL instance. | `string` | `"appdb"` | no |
| <a name="input_database_version"></a> [database\_version](#input\_database\_version) | PostgreSQL version | `string` | `"POSTGRES_15"` | no |
| <a name="input_db_user"></a> [db\_user](#input\_db\_user) | Username for the initial database user created on the instance. | `string` | `"appuser"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Deletion protection | `bool` | `true` | no |
| <a name="input_max_connections"></a> [max\_connections](#input\_max\_connections) | Maximum number of connections | `string` | `"100"` | no |
| <a name="input_public_ip"></a> [public\_ip](#input\_public\_ip) | Enable public IP | `bool` | `false` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region for the Cloud SQL instance. Must match the VPC region for Private Service Access (PSA) connectivity. | `string` | `"us-central1"` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Instance tier (e.g., db-f1-micro, db-n1-standard-1) | `string` | `"db-f1-micro"` | no |
| <a name="input_vpc_network_id"></a> [vpc\_network\_id](#input\_vpc\_network\_id) | VPC network ID for private connectivity | `string` | `null` | no |
| <a name="input_vpc_peering_id"></a> [vpc\_peering\_id](#input\_vpc\_peering\_id) | ID of the VPC peering connection for Private Service Access (PSA). Not used to configure the instance; exists only to declare an explicit Terraform dependency so the PSA peering is fully established before the instance is created. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_name"></a> [connection\_name](#output\_connection\_name) | Instance connection name (for Cloud SQL Proxy) |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Database name |
| <a name="output_db_user"></a> [db\_user](#output\_db\_user) | Database user |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Instance private IP address |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Instance public IP address |
<!-- END_TF_DOCS -->
