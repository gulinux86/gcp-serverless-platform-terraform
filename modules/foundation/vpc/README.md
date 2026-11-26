# vpc

VPC network with a VPC-native GKE node subnet (primary range for nodes, secondary ranges for pods and Services), VPC flow logs, and Private Service Access (PSA) peering for Cloud SQL. Manages the full PSA lifecycle including the reserved IP range, service networking connection, and destroy-time sequencing.

## Usage

```hcl
module "vpc" {
  source = "../modules/foundation/vpc"

  name                = "app"
  region              = "us-central1"
  private_subnet_cidr = "10.0.0.0/22"
  pods_cidr           = "10.4.0.0/16"
  services_cidr       = "10.8.0.0/20"
}
```

## Known Behaviors

### PSA range is required for Cloud SQL private IP

This module provisions a `/16` PSA address range and service networking connection for `servicenetworking.googleapis.com`. This is a prerequisite for Cloud SQL instances with private IP. The Cloud SQL module must receive `vpc_peering_id` from this module's output to ensure it waits until the peering is established before creating the instance.

### PSA lock release on destroy — 10-minute buffer

After the subnet is deleted, GCP holds internal PSA locks for several minutes before releasing them. If the peering is deleted while the locks are still held, the API call returns an error. A `time_sleep` resource with `destroy_duration = "600s"` fires between subnet deletion and PSA connection deletion to absorb this delay.

Destroy ordering:
```
subnet deleted → 600s time_sleep → PSA connection abandoned
  → PSA range deleted → VPC deleted
```

### PSA deletion policy is ABANDON

The `google_service_networking_connection` is configured with `deletion_policy = "ABANDON"`. This means Terraform does not call the GCP API to delete the peering — it abandons it and lets GCP clean up when the network is deleted. This avoids intermittent API errors that occur when attempting to delete an active peering connection.

### VPC-native secondary ranges

The node subnet carries two named secondary ranges, exported as
`pods_range_name` and `services_range_name`. The GKE cluster references them by
name in its `ip_allocation_policy`; renaming one forces the cluster to be
recreated. Size the pod range for the node ceiling: each node reserves a `/24`
out of it at the default 110 pods per node.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_global_address.private_ip_alloc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_service_networking_connection.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [time_sleep.decommissioning_buffer](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_name"></a> [name](#input\_name) | Base name prefix for VPC and subnet resources. For example, 'app' produces 'app-vpc' and 'app-vpc-private'. | `string` | n/a | yes |
| <a name="input_log_aggregation_interval"></a> [log\_aggregation\_interval](#input\_log\_aggregation\_interval) | VPC flow log aggregation interval. Valid values: INTERVAL\_5\_SEC, INTERVAL\_30\_SEC, INTERVAL\_1\_MIN, INTERVAL\_5\_MIN, INTERVAL\_10\_MIN, INTERVAL\_15\_MIN. | `string` | `"INTERVAL_5_SEC"` | no |
| <a name="input_log_flow_sampling"></a> [log\_flow\_sampling](#input\_log\_flow\_sampling) | Log flow sampling rate (0.0 to 1.0) | `number` | `0.5` | no |
| <a name="input_pods_cidr"></a> [pods\_cidr](#input\_pods\_cidr) | Secondary range for pod IPs (VPC-native alias IPs). Must not overlap the primary range, the Service range or the PSA range. | `string` | `"10.4.0.0/16"` | no |
| <a name="input_private_subnet_cidr"></a> [private\_subnet\_cidr](#input\_private\_subnet\_cidr) | Primary range of the node subnet. Each GKE node takes one address from here. | `string` | `"10.0.0.0/22"` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region for subnet and PSA range creation. Must match the region of the GKE cluster and Cloud SQL instance that connect to this network. | `string` | `"us-central1"` | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | Routing mode (REGIONAL or GLOBAL) | `string` | `"GLOBAL"` | no |
| <a name="input_services_cidr"></a> [services\_cidr](#input\_services\_cidr) | Secondary range for Kubernetes Service ClusterIPs. Must not overlap the primary range, the pod range or the PSA range. | `string` | `"10.8.0.0/20"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network_id"></a> [network\_id](#output\_network\_id) | VPC network ID |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | VPC network name |
| <a name="output_pods_range_name"></a> [pods\_range\_name](#output\_pods\_range\_name) | Name of the secondary range GKE allocates pod IPs from |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | Node subnet ID |
| <a name="output_private_subnet_name"></a> [private\_subnet\_name](#output\_private\_subnet\_name) | Node subnet name |
| <a name="output_psa_connection_id"></a> [psa\_connection\_id](#output\_psa\_connection\_id) | PSA connection ID |
| <a name="output_psa_range_name"></a> [psa\_range\_name](#output\_psa\_range\_name) | PSA range name |
| <a name="output_services_range_name"></a> [services\_range\_name](#output\_services\_range\_name) | Name of the secondary range GKE allocates Service ClusterIPs from |
<!-- END_TF_DOCS -->
