# pubsub

Pub/Sub topic with optional subscription.

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
| [google_pubsub_subscription.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_topic_name"></a> [topic\_name](#input\_topic\_name) | Pub/Sub topic name | `string` | n/a | yes |
| <a name="input_ack_deadline_seconds"></a> [ack\_deadline\_seconds](#input\_ack\_deadline\_seconds) | ACK deadline in seconds | `number` | `20` | no |
| <a name="input_create_subscription"></a> [create\_subscription](#input\_create\_subscription) | Automatically create a subscription | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Topic labels | `map(string)` | `{}` | no |
| <a name="input_maximum_backoff"></a> [maximum\_backoff](#input\_maximum\_backoff) | Maximum backoff in seconds | `string` | `"600s"` | no |
| <a name="input_message_retention_duration"></a> [message\_retention\_duration](#input\_message\_retention\_duration) | Message retention duration (e.g., 604800s for 7 days) | `string` | `"604800s"` | no |
| <a name="input_minimum_backoff"></a> [minimum\_backoff](#input\_minimum\_backoff) | Minimum backoff in seconds | `string` | `"10s"` | no |
| <a name="input_subscription_name"></a> [subscription\_name](#input\_subscription\_name) | Subscription name (optional, defaults to topic\_name-sub) | `string` | `null` | no |
| <a name="input_subscription_ttl"></a> [subscription\_ttl](#input\_subscription\_ttl) | Subscription TTL (e.g., 2592000s for 30 days) | `string` | `"2592000s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Pub/Sub subscription ID |
| <a name="output_subscription_name"></a> [subscription\_name](#output\_subscription\_name) | Pub/Sub subscription name |
| <a name="output_topic_id"></a> [topic\_id](#output\_topic\_id) | Pub/Sub topic ID |
| <a name="output_topic_name"></a> [topic\_name](#output\_topic\_name) | Pub/Sub topic name |
<!-- END_TF_DOCS -->
