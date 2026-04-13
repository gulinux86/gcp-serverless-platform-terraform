## ADDED Requirements

### Requirement: compliant-cache-key-policy
The Cloud CDN configuration for Backend Buckets MUST only use supported `cache_key_policy` arguments, such as `query_string_whitelist` and `include_http_headers`.

#### Scenario: Verify policy arguments
- **WHEN** the `google_compute_backend_bucket` is defined
- **THEN** it MUST NOT contain `include_host`, `include_protocol`, or `include_query_string` within its `cache_key_policy`.

### Requirement: valid-cdn-module
The `cloud_cdn` module MUST pass Terraform validation to ensure it can be correctly integrated into the workload layer.

#### Scenario: Module validation
- **WHEN** `terraform validate` is run in the `modules/workload/cloud_cdn/` directory
- **THEN** it MUST return a success status.
