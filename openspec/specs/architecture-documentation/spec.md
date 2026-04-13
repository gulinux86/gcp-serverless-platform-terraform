## ADDED Requirements

### Requirement: architecture-diagram
`ARCHITECTURE.md` SHALL contain a full ASCII architecture diagram showing all major components and the traffic/data flow between them, from the public internet through Cloud Armor, the Load Balancer, Cloud Run services, and Cloud SQL.

#### Scenario: Diagram renders correctly
- **WHEN** `ARCHITECTURE.md` is viewed in any standard Markdown renderer
- **THEN** the ASCII diagram SHALL be legible and show the complete request path and data layer

### Requirement: layer-descriptions
`ARCHITECTURE.md` SHALL describe each infrastructure layer (Foundation and Workload) with the resources it contains and its responsibilities.

#### Scenario: Reader understands layer separation
- **WHEN** a new contributor reads the layer descriptions
- **THEN** they SHALL understand why foundation and workload are separate Terraform root modules and what each owns

### Requirement: security-model-section
`ARCHITECTURE.md` SHALL include a security model section covering: Cloud Armor WAF coverage, ingress restrictions per service, IAM Principle of Least Privilege, secret rotation, and audit logging.

#### Scenario: Security posture is clear
- **WHEN** a security reviewer reads the document
- **THEN** they SHALL be able to understand the defense-in-depth layers without reading the Terraform code

### Requirement: destroy-orchestration-note
`ARCHITECTURE.md` SHALL document the destroy-time dependency ordering and the reason for the `time_sleep` resources, so operators understand the teardown behavior.

#### Scenario: Operator understands teardown timing
- **WHEN** an operator runs `terraform destroy`
- **THEN** the architecture doc prepares them to expect a 2-10 minute teardown due to VPC Egress IP release and PSA decommission buffers
