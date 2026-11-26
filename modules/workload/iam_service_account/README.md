# iam_service_account

Service account with configurable IAM role bindings and optional GKE Workload Identity bindings (`workload_identity_ksas`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_key.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Service account ID (the part of the email before @) | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_create_key"></a> [create\_key](#input\_create\_key) | Create service account key | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Service account description | `string` | `"Service account managed by Terraform"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Service account display name | `string` | `""` | no |
| <a name="input_iam_roles"></a> [iam\_roles](#input\_iam\_roles) | Map of IAM roles to assign to the service account in the project | `map(string)` | `{}` | no |
| <a name="input_public_key_type"></a> [public\_key\_type](#input\_public\_key\_type) | Public key type (TYPE\_X509\_PEM\_FILE or TYPE\_RAW\_PUBLIC\_KEY) | `string` | `"TYPE_X509_PEM_FILE"` | no |
| <a name="input_service_account_iam_roles"></a> [service\_account\_iam\_roles](#input\_service\_account\_iam\_roles) | Map of members and roles for the service account's own IAM | `map(string)` | `{}` | no |
| <a name="input_workload_identity_ksas"></a> [workload\_identity\_ksas](#input\_workload\_identity\_ksas) | Kubernetes service accounts, as "<namespace>/<name>", allowed to impersonate this SA through GKE Workload Identity. | `list(string)` | `[]` | no |
| <a name="input_workload_identity_pool"></a> [workload\_identity\_pool](#input\_workload\_identity\_pool) | Workload Identity pool (<project>.svc.id.goog). Required when workload\_identity\_ksas is set. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_email"></a> [email](#output\_email) | Service account email |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | Service account key ID (null when create\_key = false) |
| <a name="output_name"></a> [name](#output\_name) | Fully qualified service account name (projects/PROJECT/serviceAccounts/EMAIL) |
| <a name="output_unique_id"></a> [unique\_id](#output\_unique\_id) | Service account unique numeric ID |
| <a name="output_workload_identity_annotation"></a> [workload\_identity\_annotation](#output\_workload\_identity\_annotation) | Annotation to put on the Kubernetes service account(s) bound to this SA |
<!-- END_TF_DOCS -->
