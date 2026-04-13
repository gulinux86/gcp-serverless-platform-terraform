# secret_manager

Secret Manager secret with optional rotation configuration.

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
| [google_secret_manager_secret.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_secret_id"></a> [secret\_id](#input\_secret\_id) | Secret ID (unique name) | `string` | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Secret labels | `map(string)` | `{}` | no |
| <a name="input_rotation_period"></a> [rotation\_period](#input\_rotation\_period) | ISO 8601 duration for automatic rotation notifications, e.g. '2592000s' for 30 days | `string` | `null` | no |
| <a name="input_rotation_topic_id"></a> [rotation\_topic\_id](#input\_rotation\_topic\_id) | Pub/Sub topic ID to receive rotation notifications | `string` | `null` | no |
| <a name="input_secret_value"></a> [secret\_value](#input\_secret\_value) | Secret value (optional, can be defined later) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secret_id"></a> [secret\_id](#output\_secret\_id) | Full secret resource ID (projects/PROJECT/secrets/SECRET) — use for IAM bindings |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Full secret name |
| <a name="output_secret_version"></a> [secret\_version](#output\_secret\_version) | Secret version (if created) |
<!-- END_TF_DOCS -->
