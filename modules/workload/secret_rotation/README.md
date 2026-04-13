# secret_rotation

Infrastructure for automatic Secret Manager secret rotation. Provisions the complete rotation loop: Pub/Sub topic → Secret Manager IAM → Cloud Run Job handler → Pub/Sub push subscription with OIDC authentication.

This module owns the rotation *plumbing* only. Individual secrets opt into rotation by passing this module's `topic_id` output to the `secret_manager` module's `rotation_topic_id` input.

## Usage

```hcl
module "secret_rotation" {
  source = "../modules/workload/secret_rotation"

  name       = "app"
  project_id = var.project_id
  region     = "us-central1"
}

module "app_secret" {
  source = "../modules/workload/secret_manager"

  secret_id         = "app-api-key"
  secret_value      = var.api_secret_key
  rotation_period   = "2592000s"
  rotation_topic_id = module.secret_rotation.topic_id
}
```

## Rotation Loop

```
Secret Manager
  │
  │  rotation notification (after rotation_period)
  ▼
Pub/Sub topic  ──[push subscription]──▶  Cloud Run Job (handler)
                 (OIDC-authenticated)
```

1. Secret Manager publishes a rotation notification to the Pub/Sub topic when a secret's rotation period elapses.
2. A push subscription delivers the message to the Cloud Run Job via OIDC-authenticated HTTP.
3. The Cloud Run Job executes the rotation logic (placeholder image by default — replace with your actual rotation handler).

## Known Behaviors

### Rotation does not auto-update consumers

When the rotation handler generates a new secret version, **consumers of the secret are not automatically notified or restarted**. Cloud Run services that inject secrets as environment variables must be redeployed to pick up the new version. If using `version = "latest"`, the new value is available on the next cold start; warm instances continue using the old value until they are replaced.

### The handler image is a placeholder

`handler_image` defaults to `gcr.io/cloudrun/hello`. This will receive rotation events but will not actually rotate any credentials. Replace this with your rotation handler image before enabling rotation on real secrets.

### Invoker service account is scoped to this job

The `<name>-rotation-invoker` service account has `roles/run.invoker` on this specific Cloud Run Job only. It cannot invoke any other Cloud Run service or job.

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
| [google_cloud_run_v2_job.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job) | resource |
| [google_cloud_run_v2_job_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job_iam_member) | resource |
| [google_pubsub_subscription.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_pubsub_topic_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_service_account.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources in this module | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Deployment region | `string` | n/a | yes |
| <a name="input_ack_deadline_seconds"></a> [ack\_deadline\_seconds](#input\_ack\_deadline\_seconds) | Pub/Sub subscription acknowledgement deadline in seconds | `number` | `60` | no |
| <a name="input_handler_image"></a> [handler\_image](#input\_handler\_image) | Container image for the secret rotation handler Cloud Run Job | `string` | `"gcr.io/cloudrun/hello"` | no |
| <a name="input_message_retention_duration"></a> [message\_retention\_duration](#input\_message\_retention\_duration) | Pub/Sub subscription message retention duration | `string` | `"600s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_invoker_sa_email"></a> [invoker\_sa\_email](#output\_invoker\_sa\_email) | Email of the service account used to authenticate Pub/Sub push to the rotation handler job |
| <a name="output_topic_id"></a> [topic\_id](#output\_topic\_id) | Full resource ID of the secret rotation Pub/Sub topic |
| <a name="output_topic_name"></a> [topic\_name](#output\_topic\_name) | Name of the secret rotation Pub/Sub topic |
<!-- END_TF_DOCS -->
