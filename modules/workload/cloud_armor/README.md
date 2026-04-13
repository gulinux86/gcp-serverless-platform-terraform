# cloud_armor

Cloud Armor WAF security policy with OWASP Top 10 managed rules, per-IP rate limiting, and ML-based Adaptive Protection. Creates the security policy only — it must be attached to a backend service separately via the `https_load_balancer` module.

## Usage

```hcl
module "cloud_armor" {
  source = "../modules/workload/cloud_armor"

  project_id           = var.project_id
  name                 = "app-armor"
  rate_limit_threshold = 100
}

module "lb" {
  source = "../modules/workload/https_load_balancer"
  # ...
  security_policy_id = module.cloud_armor.security_policy_self_link
}
```

## Rules Configured

| Priority | Action | Description |
|---|---|---|
| 1000 | `deny(403)` | OWASP XSS — `xss-v33-stable` |
| 1001 | `deny(403)` | OWASP SQLi — `sqli-v33-stable` |
| 2000 | `throttle` → `deny(429)` | Rate limit: `rate_limit_threshold` req/min per IP |
| 2147483647 | `allow` | Default allow (lowest priority) |

Adaptive Protection (ML-based L7 DDoS defense) is enabled on all policies.

## Known Behaviors

### Attachment is not automatic

This module creates the security policy but does **not** attach it to any backend service. Pass `module.cloud_armor.security_policy_self_link` to the `security_policy_id` input of the `https_load_balancer` module. If not attached, requests bypass Cloud Armor entirely.

### Rate limit is per-IP, per-minute

The rate limit applies independently to each source IP. `rate_limit_threshold = 100` allows 100 requests per minute per IP. Requests exceeding the threshold receive HTTP 429.

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
| [google_compute_security_policy.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Base name for load balancer resources | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP Project ID | `string` | n/a | yes |
| <a name="input_rate_limit_threshold"></a> [rate\_limit\_threshold](#input\_rate\_limit\_threshold) | Maximum requests per minute per IP before rate limiting kicks in | `number` | `100` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_security_policy_name"></a> [security\_policy\_name](#output\_security\_policy\_name) | Name of the Cloud Armor security policy |
| <a name="output_security_policy_self_link"></a> [security\_policy\_self\_link](#output\_security\_policy\_self\_link) | Self-link of the Cloud Armor security policy, used to attach to a backend service |
<!-- END_TF_DOCS -->
