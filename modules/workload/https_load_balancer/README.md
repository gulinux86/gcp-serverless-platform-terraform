# https_load_balancer

Global HTTPS Load Balancer with optional path-based routing, managed SSL certificate, and Cloud Armor security policy attachment. Fronts one or two Cloud Run v2 services (frontend + API backend) using Serverless NEGs.

## Usage

### Single service (frontend only)

```hcl
module "lb" {
  source = "../modules/workload/https_load_balancer"

  project_id             = var.project_id
  region                 = "us-central1"
  name                   = "app-lb"
  cloud_run_service_name = module.frontend.name
  domain                 = "example.com"
  security_policy_id     = module.cloud_armor.security_policy_self_link
}
```

### Path-based routing (frontend + API backend)

```hcl
module "lb" {
  source = "../modules/workload/https_load_balancer"

  project_id                 = var.project_id
  region                     = "us-central1"
  name                       = "app-lb"
  cloud_run_service_name     = module.frontend.name
  api_cloud_run_service_name = module.backend.name
  api_path_prefix            = "/api"
  domain                     = "example.com"
  security_policy_id         = module.cloud_armor.security_policy_self_link
}
```

## Known Behaviors

### `domain = null` — HTTP only (no TLS)

When `domain` is omitted, the load balancer provisions an HTTP-only forwarding rule with no managed SSL certificate. This is useful for development and testing but **must not be used in production**. TLS is only configured when `domain` is set to a valid domain name.

### Path-based routing

When `api_cloud_run_service_name` is set, the URL map routes as follows:

```
<api_path_prefix>        → api backend Cloud Run service
<api_path_prefix>/*      → api backend Cloud Run service
*                        → frontend Cloud Run service (default)
```

The default `api_path_prefix` is `/api`. Both the exact prefix and all sub-paths are routed to the API. Cloud Armor is applied to both backend services when `security_policy_id` is provided.

### Cloud Armor is not automatic

`security_policy_id` is optional. When not provided, Cloud Armor is not attached and requests are not filtered. In production, always attach a security policy via the `cloud_armor` module.

### `count` expressions require non-computed values

The `api_cloud_run_service_name` variable is used in `count` expressions. It must be resolvable at plan time. Pass `module.backend.name` (which outputs `var.name`, a static value) rather than a computed attribute like `google_cloud_run_v2_service.this.name`. If you see `The "count" value depends on resource attributes that cannot be determined until apply`, verify the source of the service name value.

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
| [google_compute_backend_service.api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_backend_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_global_address.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_managed_ssl_certificate.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate) | resource |
| [google_compute_region_network_endpoint_group.api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group) | resource |
| [google_compute_region_network_endpoint_group.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group) | resource |
| [google_compute_target_http_proxy.redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_https_proxy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.with_api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_run_service_name"></a> [cloud\_run\_service\_name](#input\_cloud\_run\_service\_name) | Name of the Cloud Run service to front with this load balancer | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Base name for load balancer resources | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Cloud Run service region | `string` | n/a | yes |
| <a name="input_api_cloud_run_service_name"></a> [api\_cloud\_run\_service\_name](#input\_api\_cloud\_run\_service\_name) | Name of the Cloud Run service for the API backend. When set, enables path-based routing: api\_path\_prefix/* → this service, default → cloud\_run\_service\_name. | `string` | `null` | no |
| <a name="input_api_path_prefix"></a> [api\_path\_prefix](#input\_api\_path\_prefix) | URL path prefix to route to the API backend (e.g., /api). Only used when api\_cloud\_run\_service\_name is set. | `string` | `"/api"` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Custom domain for the managed SSL certificate (optional) | `string` | `null` | no |
| <a name="input_security_policy_id"></a> [security\_policy\_id](#input\_security\_policy\_id) | Cloud Armor security policy self\_link to attach to the backend service (optional) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_backend_service_self_link"></a> [api\_backend\_service\_self\_link](#output\_api\_backend\_service\_self\_link) | Self-link of the API backend service (null when api\_cloud\_run\_service\_name is not set) |
| <a name="output_load_balancer_ip"></a> [load\_balancer\_ip](#output\_load\_balancer\_ip) | Global IP address of the HTTPS load balancer |
| <a name="output_ssl_certificate_name"></a> [ssl\_certificate\_name](#output\_ssl\_certificate\_name) | Name of the managed SSL certificate (null when domain not set) |
<!-- END_TF_DOCS -->
