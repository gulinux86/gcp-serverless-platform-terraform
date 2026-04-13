## ADDED Requirements

### Requirement: cloud-monitoring-alerting
The workload SHALL have Cloud Monitoring alert policies for critical signals: Cloud Run error rate, Cloud Run p99 latency, Cloud Armor block rate, and Cloud SQL disk utilization.

#### Scenario: High error rate triggers alert
- **WHEN** the Cloud Run service error rate exceeds 1% over a 5-minute window
- **THEN** a Cloud Monitoring alert SHALL fire and notify the configured notification channel

#### Scenario: High latency triggers alert
- **WHEN** Cloud Run p99 request latency exceeds 2 seconds over a 5-minute window
- **THEN** a Cloud Monitoring alert SHALL fire

#### Scenario: Cloud SQL disk usage alert
- **WHEN** Cloud SQL disk utilization exceeds 80%
- **THEN** a Cloud Monitoring alert SHALL fire

### Requirement: vpc-flow-logs
The private VPC subnet SHALL have flow logs enabled to capture network traffic metadata for security investigation and compliance.

#### Scenario: Flow logs captured for private subnet
- **WHEN** network traffic flows through the private subnet
- **THEN** flow log records SHALL be written to Cloud Logging with 50% sampling and 5-second aggregation intervals

### Requirement: audit-log-sink
Cloud Audit Logs (Admin Activity and Data Access) SHALL be exported to a dedicated GCS bucket for long-term retention and compliance audit trails.

#### Scenario: Audit events exported to GCS
- **WHEN** an IAM, resource, or data access audit event occurs in the project
- **THEN** the event SHALL be exported to the audit log GCS bucket within the sink's export interval
