# gke_node_pool

GKE node pool with an independent lifecycle: dedicated node service account (the Compute Engine default SA is rejected by validation), `GKE_METADATA` for Workload Identity, shielded boot, auto-repair/auto-upgrade, surge upgrades with no capacity loss, optional Spot VMs.

## Usage

```hcl
module "node_pool" {
  source = "../modules/foundation/gke_node_pool"

  name                  = "app-hml-default"
  project_id            = var.project_id
  cluster_id            = module.gke.id
  location              = module.gke.location
  machine_type          = "e2-standard-2"
  spot                  = true
  min_node_count        = 1
  max_node_count        = 3 # per zone
  service_account_email = module.node_sa.email
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
| [google_container_node_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID of the cluster this pool belongs to. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Cluster location (region or zone). Must match the cluster's. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Node pool name. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Dedicated node service account. Must not be the Compute Engine default SA. | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Boot disk size per node, in GB. | `number` | `50` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Boot disk type: pd-standard, pd-balanced or pd-ssd. | `string` | `"pd-balanced"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Kubernetes labels applied to every node. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Compute Engine machine type for the nodes. | `string` | `"e2-standard-2"` | no |
| <a name="input_max_node_count"></a> [max\_node\_count](#input\_max\_node\_count) | Autoscaler maximum, per zone. | `number` | `3` | no |
| <a name="input_min_node_count"></a> [min\_node\_count](#input\_min\_node\_count) | Autoscaler minimum, per zone. | `number` | `1` | no |
| <a name="input_network_tags"></a> [network\_tags](#input\_network\_tags) | Network tags on the node VMs, for firewall targeting. | `list(string)` | `[]` | no |
| <a name="input_node_locations"></a> [node\_locations](#input\_node\_locations) | Zones to place nodes in. Empty uses the cluster's zones. | `list(string)` | `[]` | no |
| <a name="input_spot"></a> [spot](#input\_spot) | Run on Spot VMs: much cheaper, preemptible at any time. Fine for hml; keep production on on-demand capacity. | `bool` | `false` | no |
| <a name="input_taints"></a> [taints](#input\_taints) | Kubernetes taints applied to every node. | <pre>list(object({<br/>    key    = string<br/>    value  = string<br/>    effect = string<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Node pool ID |
| <a name="output_name"></a> [name](#output\_name) | Node pool name |
<!-- END_TF_DOCS -->
