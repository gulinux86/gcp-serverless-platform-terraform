# cloud_run_service

Cloud Run v2 service with Direct VPC Egress, optional GCS FUSE volume mount, and Secret Manager environment variable injection. Configures ingress restriction, min-instance scaling, and a per-service destroy cooldown for safe subnet deletion.

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
  vpc_subnet_id         = var.private_subnet_id

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

### Direct VPC Egress IP reservation cooldown

When a Cloud Run v2 service uses Direct VPC Egress, GCP internally reserves IP addresses (`serverless-ipv4-*`) on the subnet. These reservations are **not released immediately** when the Cloud Run service is deleted — GCP holds them for up to 120 minutes. During this window, `terraform destroy` will fail when attempting to delete the subnet:

```
Error: The subnetwork resource '...app-vpc-private' is already being used by
'...addresses/serverless-ipv4-1234567890'
```

This module includes a `time_sleep` resource with a 150-second destroy duration to delay module completion after Cloud Run is deleted, giving GCP time to start releasing reservations. However, 150 seconds is insufficient for the full 120-minute window.

**Recommended destroy pattern**: use two phases — destroy workload first, wait for GCP to release reservations, then destroy foundation. See the root `README.md` for the full two-phase destroy procedure.

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
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloud_run_v2_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.noauth](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [time_sleep.wait_for_ip_release](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

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
| <a name="input_vpc_subnet_id"></a> [vpc\_subnet\_id](#input\_vpc\_subnet\_id) | VPC Subnet ID for Direct VPC Egress | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_decommission_signal"></a> [decommission\_signal](#output\_decommission\_signal) | Signal indicating that the service and its cooldown are finished |
| <a name="output_name"></a> [name](#output\_name) | Cloud Run service name |
| <a name="output_service_url"></a> [service\_url](#output\_service\_url) | Public URL of the Cloud Run service |
<!-- END_TF_DOCS -->
