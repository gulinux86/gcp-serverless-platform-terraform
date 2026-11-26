# argocd

Argo CD installed bare by the Helm provider: CRDs and controllers, no Application, no repository. Ported from `eks-terraform/workload/modules/argocd`. CRDs are kept on uninstall (`crds.keep`) so a `helm uninstall` cannot cascade-delete every Application; the server is `ClusterIP` — reach the UI with the `port_forward_command` output.

## Usage

```hcl
module "argocd" {
  source        = "../modules/workload/argocd"
  chart_version = "10.4.0"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.17 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | argo-cd Helm chart version. Pinned deliberately: an unpinned chart means a rebuild can silently install a different Argo CD than the one that was reviewed. Chart 10.4.0 ships Argo CD v3.5.1. | `string` | `"10.4.0"` | no |
| <a name="input_ha_enabled"></a> [ha\_enabled](#input\_ha\_enabled) | Run Argo CD in high-availability mode. Off by default: HA adds a redis-ha cluster (3 pods) plus extra replicas, which does not fit the small hml node pool. Turn on when the node group can carry it. | `bool` | `false` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace Argo CD is installed into. Kept separate from kube-system so its RBAC and resource footprint are isolated from the cluster's own components. | `string` | `"argocd"` | no |
| <a name="input_server_service_type"></a> [server\_service\_type](#input\_server\_service\_type) | Kubernetes Service type for the Argo CD API/UI server. ClusterIP by default — nothing is exposed and access is via `kubectl port-forward`. Exposing the UI is a separate, deliberate change: it needs an ingress, TLS and an authentication story. | `string` | `"ClusterIP"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_chart_version"></a> [chart\_version](#output\_chart\_version) | Installed argo-cd chart version |
| <a name="output_initial_password_command"></a> [initial\_password\_command](#output\_initial\_password\_command) | Retrieves the generated admin password. Change it and delete the secret; it is a bootstrap credential, not a permanent one. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace Argo CD runs in |
| <a name="output_port_forward_command"></a> [port\_forward\_command](#output\_port\_forward\_command) | Nothing is exposed; reach the UI through this port-forward, then https://localhost:8080 |
<!-- END_TF_DOCS -->
