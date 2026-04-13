# artifact_registry

Artifact Registry repository for storing container images and packages.

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
| [google_artifact_registry_repository.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | Artifact Registry repository ID | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Repository description | `string` | `"Managed by Terraform"` | no |
| <a name="input_format"></a> [format](#input\_format) | Repository format. Determines what package types the repository stores. Valid values: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, KFP, GO. | `string` | `"DOCKER"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Repository labels | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Repository location | `string` | `"us-central1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | Repository ID |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Full repository name |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | Repository URL |
<!-- END_TF_DOCS -->
