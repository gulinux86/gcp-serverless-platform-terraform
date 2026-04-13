# cloud_firewall

VPC firewall rules for ingress traffic control.

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
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.deny_external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Base name for firewall rules | `string` | n/a | yes |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | VPC network name | `string` | n/a | yes |
| <a name="input_allowed_ports"></a> [allowed\_ports](#input\_allowed\_ports) | TCP ports to allow inbound. Defaults to HTTP (80), HTTPS (443), and common application port (8080). | `list(string)` | <pre>[<br/>  "80",<br/>  "443",<br/>  "8080"<br/>]</pre> | no |
| <a name="input_create_deny_rule"></a> [create\_deny\_rule](#input\_create\_deny\_rule) | When true, adds a low-priority deny-all rule for traffic not matched by any allow rule, enforcing explicit deny-by-default posture. | `bool` | `false` | no |
| <a name="input_source_ranges"></a> [source\_ranges](#input\_source\_ranges) | Source CIDR ranges for the ingress allow rule. Defaults to RFC-1918 private address space (10.0.0.0/8). | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |
| <a name="input_target_tags"></a> [target\_tags](#input\_target\_tags) | Network tags identifying instances this rule applies to. An empty list applies the rule to all instances in the network. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_rule_name"></a> [firewall\_rule\_name](#output\_firewall\_rule\_name) | Nome da regra de firewall |
<!-- END_TF_DOCS -->
