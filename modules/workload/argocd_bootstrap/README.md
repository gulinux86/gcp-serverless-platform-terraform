# argocd_bootstrap

The handover from Terraform to Argo CD, ported from `eks-terraform/workload/modules/argocd-bootstrap`: two AppProjects (`platform` may create cluster-scoped resources; `apps` is confined to namespace globs and denied ClusterRole/ClusterRoleBinding) and one root Application (app-of-apps) watching `platform_repo_path`. Shipped as a local Helm chart because `kubernetes_manifest` cannot plan Argo CD custom resources before their CRDs exist.

## Usage

```hcl
module "argocd_bootstrap" {
  source    = "../modules/workload/argocd_bootstrap"
  namespace = module.argocd.namespace

  platform_repo_url      = "https://github.com/gulinux86/gke-gitops-platform-apps"
  platform_repo_revision = "main"
  platform_repo_path     = "bootstrap/apps"
  apps_repo_url          = "https://github.com/gulinux86/gke-gitops-platform-apps"
  apps_namespaces        = ["frontend-*", "backend-*"]
  platform_source_repos  = ["https://github.com/gulinux86/gke-gitops-platform-apps", "https://charts.jetstack.io"]
  apps_source_repos      = ["https://github.com/gulinux86/gke-gitops-platform-apps"]

  depends_on = [module.argocd]
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
| [helm_release.bootstrap](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apps_namespaces"></a> [apps\_namespaces](#input\_apps\_namespaces) | Namespace patterns the apps project may deploy into. A prefix glob such as ["app-*"] avoids a Terraform change per application while keeping kube-system, gke-gateway-system, argocd and external-secrets out of reach — they do not match the prefix. | `list(string)` | n/a | yes |
| <a name="input_apps_repo_url"></a> [apps\_repo\_url](#input\_apps\_repo\_url) | Git repository that will hold applications. The apps AppProject is created ahead of the repository existing, so the privilege boundary is written and reviewed before there is pressure to bend it. | `string` | n/a | yes |
| <a name="input_apps_source_repos"></a> [apps\_source\_repos](#input\_apps\_source\_repos) | Every repository the apps project may pull from. Same rule: chart repositories count. | `list(string)` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace Argo CD runs in. The projects and the root Application are created here. | `string` | n/a | yes |
| <a name="input_platform_repo_revision"></a> [platform\_repo\_revision](#input\_platform\_repo\_revision) | Branch or tag the root Application tracks. A branch means Argo follows every commit; a tag means promotions are explicit. | `string` | n/a | yes |
| <a name="input_platform_repo_url"></a> [platform\_repo\_url](#input\_platform\_repo\_url) | Git repository holding platform components. The platform AppProject accepts sources only from here. | `string` | n/a | yes |
| <a name="input_platform_source_repos"></a> [platform\_source\_repos](#input\_platform\_source\_repos) | Every repository the platform project may pull from, Helm chart repositories included. A multi-source Application takes its chart from one repo and its values from another, and Argo CD checks both — listing only the Git repository fails every chart-based component. | `list(string)` | n/a | yes |
| <a name="input_platform_repo_path"></a> [platform\_repo\_path](#input\_platform\_repo\_path) | Directory of the platform repository the root Application watches. It must hold Application/ApplicationSet manifests only. | `string` | `"apps"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_root_application"></a> [root\_application](#output\_root\_application) | Name of the root Application Terraform hands the cluster over with |
<!-- END_TF_DOCS -->
