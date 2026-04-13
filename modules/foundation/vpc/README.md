# vpc

VPC network with private subnets, VPC flow logs, and Private Service Access (PSA) peering for Cloud SQL. Manages the full PSA lifecycle including the reserved IP range, service networking connection, and destroy-time sequencing.

## Usage

```hcl
module "vpc" {
  source = "../modules/foundation/vpc"

  name                = "app"
  region              = "us-central1"
  private_subnet_cidr = "10.0.2.0/24"
}
```

## Known Behaviors

### PSA range is required for Cloud SQL private IP

This module provisions a `/16` PSA address range and service networking connection for `servicenetworking.googleapis.com`. This is a prerequisite for Cloud SQL instances with private IP. The Cloud SQL module must receive `vpc_peering_id` from this module's output to ensure it waits until the peering is established before creating the instance.

### PSA lock release on destroy — 10-minute buffer

After the subnet is deleted, GCP holds internal PSA locks for several minutes before releasing them. If the peering is deleted while the locks are still held, the API call returns an error. A `time_sleep` resource with `destroy_duration = "600s"` fires between subnet deletion and PSA connection deletion to absorb this delay.

Destroy ordering:
```
Cloud Run deleted → serverless IP cooldown → subnet deleted
  → 600s time_sleep → PSA connection abandoned → PSA range deleted → VPC deleted
```

### PSA deletion policy is ABANDON

The `google_service_networking_connection` is configured with `deletion_policy = "ABANDON"`. This means Terraform does not call the GCP API to delete the peering — it abandons it and lets GCP clean up when the network is deleted. This avoids intermittent API errors that occur when attempting to delete an active peering connection.

### `serverless_decommission_signal`

When provided, the private subnet depends on this signal before it can be destroyed. Pass the `decommission_signal` output from the `cloud_run_service` module instances to ensure serverless IP reservations are released before subnet deletion is attempted.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_global_address.private_ip_alloc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.private_2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_service_networking_connection.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [terraform_data.serverless_signal](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_sleep.decommissioning_buffer](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Base name prefix for VPC and subnet resources. For example, 'app' produces 'app-vpc' and 'app-vpc-private'. | `string` | n/a | yes |
| <a name="input_log_aggregation_interval"></a> [log\_aggregation\_interval](#input\_log\_aggregation\_interval) | VPC flow log aggregation interval. Valid values: INTERVAL\_5\_SEC, INTERVAL\_30\_SEC, INTERVAL\_1\_MIN, INTERVAL\_5\_MIN, INTERVAL\_10\_MIN, INTERVAL\_15\_MIN. | `string` | `"INTERVAL_5_SEC"` | no |
| <a name="input_log_flow_sampling"></a> [log\_flow\_sampling](#input\_log\_flow\_sampling) | Log flow sampling rate (0.0 to 1.0) | `number` | `0.5` | no |
| <a name="input_private_subnet_cidr"></a> [private\_subnet\_cidr](#input\_private\_subnet\_cidr) | Primary private subnet CIDR | `string` | `"10.0.2.0/24"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region for subnet and PSA range creation. Must match the region of workload resources (Cloud Run, Cloud SQL) that connect to this network. | `string` | `"us-central1"` | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | Routing mode (REGIONAL or GLOBAL) | `string` | `"GLOBAL"` | no |
| <a name="input_secondary_subnet_cidr"></a> [secondary\_subnet\_cidr](#input\_secondary\_subnet\_cidr) | Secondary private subnet CIDR (must not overlap with primary or PSA range) | `string` | `"10.0.3.0/24"` | no |
| <a name="input_serverless_decommission_signal"></a> [serverless\_decommission\_signal](#input\_serverless\_decommission\_signal) | Signal from the workload layer indicating serverless IP cooldowns are complete. When provided, the private subnetwork will depend on it to enforce correct destruction ordering. | `map(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | VPC network ID |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | VPC network name |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | Private subnet ID |
| <a name="output_private_subnet_name"></a> [private\_subnet\_name](#output\_private\_subnet\_name) | Private subnet name |
| <a name="output_psa_connection_id"></a> [psa\_connection\_id](#output\_psa\_connection\_id) | PSA connection ID |
| <a name="output_psa_range_name"></a> [psa\_range\_name](#output\_psa\_range\_name) | PSA range name |
| <a name="output_secondary_subnet_id"></a> [secondary\_subnet\_id](#output\_secondary\_subnet\_id) | Secondary private subnet ID |
| <a name="output_secondary_subnet_name"></a> [secondary\_subnet\_name](#output\_secondary\_subnet\_name) | Secondary private subnet name |
<!-- END_TF_DOCS -->
