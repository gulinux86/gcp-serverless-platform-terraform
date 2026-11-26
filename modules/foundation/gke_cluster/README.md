# gke_cluster

GKE Standard cluster: private nodes, private IP endpoint, VPC-native, Workload Identity, Dataplane V2 (NetworkPolicy), Gateway API, shielded nodes, managed Prometheus. The default node pool is removed; pools come from `gke_node_pool`.

## Usage

```hcl
module "gke" {
  source = "../modules/foundation/gke_cluster"

  name                = "app-hml-gke"
  project_id          = var.project_id
  location            = "us-central1-a" # zone = zonal (free tier); region = regional
  network_id          = module.vpc.network_id
  subnet_id           = module.vpc.private_subnet_id
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  deletion_protection = false
}
```

## Known Behaviors

### Control plane access goes through the DNS endpoint

The IP endpoint is internal (`enable_private_endpoint = true`), so nothing outside
the VPC reaches it. The DNS endpoint (`dns_endpoint` output) is open to external
traffic but authorised **per request by IAM** (`container.clusters.connect`), not
by source IP. CI and operators use it:

```bash
gcloud container clusters get-credentials <name> --location <location> --dns-endpoint
```

It is served with a publicly trusted certificate, so a Helm/Kubernetes provider
needs only `host` and an OAuth `token` — no `cluster_ca_certificate`.

### `remove_default_node_pool` deprecation warning

Provider 7.x warns that, from GKE 1.36.4, `initial_node_count = 0` replaces
`remove_default_node_pool`. The old form is kept because it works on every
version the release channels currently serve; switch once the channel floor is
past 1.36.4.

### Binary Authorization is off by default

`binary_authorization_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"` enforces the
project policy. Turn it on once the image pipeline produces attestations;
enforcing it earlier blocks every image, including Argo CD itself.

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
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | A region (regional cluster: control plane replicated across three zones) or a zone (zonal cluster: one control plane replica, covered by the GKE free tier). Use a region for production. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Cluster name. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | VPC network ID. | `string` | n/a | yes |
| <a name="input_pods_range_name"></a> [pods\_range\_name](#input\_pods\_range\_name) | Name of the subnet's secondary range for pod IPs. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID. Also names the Workload Identity pool (<project>.svc.id.goog). | `string` | n/a | yes |
| <a name="input_services_range_name"></a> [services\_range\_name](#input\_services\_range\_name) | Name of the subnet's secondary range for Service ClusterIPs. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Node subnet ID. Must carry the two secondary ranges named below. | `string` | n/a | yes |
| <a name="input_binary_authorization_mode"></a> [binary\_authorization\_mode](#input\_binary\_authorization\_mode) | DISABLED, or PROJECT\_SINGLETON\_POLICY\_ENFORCE to admit only images the project's Binary Authorization policy allows. Turn on once the image pipeline signs/attests images. | `string` | `"DISABLED"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Block `terraform destroy` of the cluster. On in production; off where the environment is torn down routinely. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Resource labels applied to the cluster. | `map(string)` | `{}` | no |
| <a name="input_maintenance_end_time"></a> [maintenance\_end\_time](#input\_maintenance\_end\_time) | End of the recurring maintenance window (RFC 3339). Only the time-of-day and duration matter. | `string` | `"2026-01-03T09:00:00Z"` | no |
| <a name="input_maintenance_recurrence"></a> [maintenance\_recurrence](#input\_maintenance\_recurrence) | RFC 5545 RRULE for the maintenance window. | `string` | `"FREQ=WEEKLY;BYDAY=SA,SU"` | no |
| <a name="input_maintenance_start_time"></a> [maintenance\_start\_time](#input\_maintenance\_start\_time) | Start of the recurring maintenance window (RFC 3339). | `string` | `"2026-01-03T03:00:00Z"` | no |
| <a name="input_master_authorized_networks"></a> [master\_authorized\_networks](#input\_master\_authorized\_networks) | Internal CIDRs allowed to reach the private IP endpoint (e.g. a VPN range). Access from outside the VPC uses the IAM-authorised DNS endpoint and needs no entry here. | <pre>list(object({<br/>    cidr_block   = string<br/>    display_name = string<br/>  }))</pre> | `[]` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | GKE release channel. The channel drives control-plane and node upgrades inside the maintenance window. | `string` | `"REGULAR"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dns_endpoint"></a> [dns\_endpoint](#output\_dns\_endpoint) | IAM-authorised DNS endpoint of the control plane (hostname, no scheme). Served with a publicly trusted certificate, so clients need no cluster CA. |
| <a name="output_id"></a> [id](#output\_id) | Cluster ID |
| <a name="output_location"></a> [location](#output\_location) | Cluster location (region or zone) |
| <a name="output_name"></a> [name](#output\_name) | Cluster name |
| <a name="output_private_endpoint"></a> [private\_endpoint](#output\_private\_endpoint) | Internal IP of the control plane, reachable only from inside the VPC |
| <a name="output_workload_identity_pool"></a> [workload\_identity\_pool](#output\_workload\_identity\_pool) | Workload Identity pool, used to build KSA members: serviceAccount:<pool>[<namespace>/<ksa>] |
<!-- END_TF_DOCS -->
