# iam_service_account

Service account with configurable IAM role bindings.

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
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_key.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Service account ID (the part of the email before @) | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_create_key"></a> [create\_key](#input\_create\_key) | Create service account key | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Service account description | `string` | `"Service account managed by Terraform"` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Service account display name | `string` | `""` | no |
| <a name="input_iam_roles"></a> [iam\_roles](#input\_iam\_roles) | Map of IAM roles to assign to the service account in the project | `map(string)` | `{}` | no |
| <a name="input_public_key_type"></a> [public\_key\_type](#input\_public\_key\_type) | Public key type (TYPE\_X509\_PEM\_FILE or TYPE\_RAW\_PUBLIC\_KEY) | `string` | `"TYPE_X509_PEM_FILE"` | no |
| <a name="input_service_account_iam_roles"></a> [service\_account\_iam\_roles](#input\_service\_account\_iam\_roles) | Map of members and roles for the service account's own IAM | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_email"></a> [email](#output\_email) | Email da service account |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | ID da chave (se criada) |
| <a name="output_name"></a> [name](#output\_name) | Nome completo da service account |
| <a name="output_unique_id"></a> [unique\_id](#output\_unique\_id) | ID único da service account |
<!-- END_TF_DOCS -->
