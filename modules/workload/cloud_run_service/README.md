# cloud_run_service

Cloud Run v2 service that egresses to the VPC through a Serverless VPC Access Connector, with an optional GCS FUSE volume mount and Secret Manager environment variable injection. Configures ingress restriction and min-instance scaling.

## Usage

```hcl
module "backend" {
  source = "../modules/workload/cloud_run_service"

  name                  = "backend"
  region                = "us-central1"
  image                 = "us-central1-docker.pkg.dev/my-project/my-repo/backend:latest"
  ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  make_public           = false
  min_instance_count    = 1
  service_account_email = module.backend_sa.email
  vpc_connector_id      = var.vpc_connector_id

  env_vars = {
    DATABASE_URL = "postgresql://user@/dbname?host=/cloudsql/project:region:instance"
  }

  secret_env_vars = {
    DB_PASSWORD = {
      secret  = "projects/my-project/secrets/db-password"
      version = "latest"
    }
  }
}
```

## Known Behaviors

### VPC Connector egress

The service routes egress through the Serverless VPC Access Connector passed in
`vpc_connector_id` (created in the foundation `vpc` module). `egress = ALL_TRAFFIC`
sends all outbound traffic through the VPC so private destinations (e.g. Cloud SQL
over PSA) stay off the public internet. When `vpc_connector_id` is `null`, no
`vpc_access` block is rendered. Unlike Direct VPC Egress, the connector holds no
per-service IP reservations in the application subnet, so there is no destroy-time
IP-release cooldown.

### `make_public` default

The default value for `make_public` is `true`. For production services behind a load balancer, always explicitly set `make_public = false` and use `ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"`.

### GCS FUSE mount

Setting `gcs_bucket_name` mounts the bucket at `mount_path` (default `/mnt/gcs`) using FUSE. The mount is read-write. FUSE performance is significantly lower than native storage — avoid using it for high-throughput I/O.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.noauth](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_image"></a> [image](#input\_image) | Container image (e.g., gcr.io/project/image:tag) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Cloud Run service name | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Container CPU | `string` | `"1"` | no |
| <a name="input_env_vars"></a> [env\_vars](#input\_env\_vars) | Container environment variables | `map(string)` | `{}` | no |
| <a name="input_gcs_bucket_name"></a> [gcs\_bucket\_name](#input\_gcs\_bucket\_name) | GCS bucket name for FUSE mount | `string` | `null` | no |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Cloud Run ingress setting. INGRESS\_TRAFFIC\_ALL allows direct *.run.app access. INGRESS\_TRAFFIC\_INTERNAL\_ONLY restricts to VPC-originating traffic. INGRESS\_TRAFFIC\_INTERNAL\_LOAD\_BALANCER allows only traffic through a Google Cloud Load Balancer (recommended for production). | `string` | `"INGRESS_TRAFFIC_INTERNAL_ONLY"` | no |
| <a name="input_make_public"></a> [make\_public](#input\_make\_public) | Whether to allow unauthenticated access | `bool` | `true` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Container memory allocation (e.g., 512Mi, 1Gi) | `string` | `"512Mi"` | no |
| <a name="input_min_instance_count"></a> [min\_instance\_count](#input\_min\_instance\_count) | Minimum number of instances to keep warm (0 = scale to zero) | `number` | `0` | no |
| <a name="input_mount_path"></a> [mount\_path](#input\_mount\_path) | Path to mount the GCS bucket | `string` | `"/mnt/gcs"` | no |
| <a name="input_region"></a> [region](#input\_region) | Deployment region | `string` | `"us-central1"` | no |
| <a name="input_secret_env_vars"></a> [secret\_env\_vars](#input\_secret\_env\_vars) | Map of env var name to Secret Manager secret reference. Each entry injects the secret value as an environment variable without exposing it as plain text. | <pre>map(object({<br/>    secret  = string<br/>    version = string<br/>  }))</pre> | `{}` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Service account email | `string` | `null` | no |
| <a name="input_vpc_connector_id"></a> [vpc\_connector\_id](#input\_vpc\_connector\_id) | Serverless VPC Access Connector ID for Cloud Run egress into the VPC. When null, no vpc\_access block is rendered. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Cloud Run service name |
| <a name="output_service_url"></a> [service\_url](#output\_service\_url) | Public URL of the Cloud Run service |
<!-- END_TF_DOCS -->
