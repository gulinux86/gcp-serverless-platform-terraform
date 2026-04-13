# cloud_storage

GCS bucket with configurable lifecycle rules, versioning, and access control.

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
| [google_storage_bucket.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Bucket name (must be globally unique) | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow bucket deletion even if not empty | `bool` | `false` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Bucket labels | `map(string)` | `{}` | no |
| <a name="input_lifecycle_action"></a> [lifecycle\_action](#input\_lifecycle\_action) | Lifecycle action (Delete, SetStorageClass) | `string` | `"Delete"` | no |
| <a name="input_lifecycle_age"></a> [lifecycle\_age](#input\_lifecycle\_age) | Age in days to apply lifecycle rule | `number` | `30` | no |
| <a name="input_location"></a> [location](#input\_location) | Bucket location | `string` | `"US"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Allow public access to the bucket | `bool` | `false` | no |
| <a name="input_uniform_bucket_level_access"></a> [uniform\_bucket\_level\_access](#input\_uniform\_bucket\_level\_access) | Enable uniform bucket-level access | `bool` | `true` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Enable object versioning | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Bucket name |
| <a name="output_bucket_self_link"></a> [bucket\_self\_link](#output\_bucket\_self\_link) | Bucket self-link |
| <a name="output_bucket_url"></a> [bucket\_url](#output\_bucket\_url) | Bucket URL |
<!-- END_TF_DOCS -->
