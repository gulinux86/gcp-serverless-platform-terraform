# cloud_nat

Cloud Router + Cloud NAT for the GKE node subnet: the only internet egress path private nodes have (public image registries, Argo CD → GitHub). Scoped to the node subnet with `LIST_OF_SUBNETWORKS`, covering its secondary (pod) ranges too. Google APIs do not need it — Private Google Access on the subnet covers them.

## Usage

```hcl
module "nat" {
  source = "../modules/foundation/cloud_nat"

  name       = "app-hml"
  region     = "us-central1"
  network_id = module.vpc.network_id
  subnet_id  = module.vpc.private_subnet_id
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.14.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.14.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Name prefix. Produces '<name>-router' and '<name>-nat'. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | VPC network ID the router is attached to. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of the router and NAT gateway. Must match the node subnet's region. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Node subnet whose primary and secondary ranges get a NAT path. | `string` | n/a | yes |
| <a name="input_log_filter"></a> [log\_filter](#input\_log\_filter) | NAT logging filter: ERRORS\_ONLY, TRANSLATIONS\_ONLY or ALL. | `string` | `"ERRORS_ONLY"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_nat_name"></a> [nat\_name](#output\_nat\_name) | Cloud NAT gateway name |
| <a name="output_router_name"></a> [router\_name](#output\_router\_name) | Cloud Router name |
<!-- END_TF_DOCS -->
