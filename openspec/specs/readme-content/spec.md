## ADDED Requirements

### Requirement: prerequisites-and-setup
The README SHALL document all prerequisites and environment setup required before running any Terraform command, including required tools and authentication steps.

#### Scenario: Reader can identify required tools
- **WHEN** an engineer reads the README before onboarding
- **THEN** they SHALL find a complete list of required CLI tools with minimum versions (Terraform, gcloud, Google provider)

#### Scenario: Reader can identify state bucket requirement
- **WHEN** an engineer is about to run terraform init for the first time
- **THEN** they SHALL find explicit instructions to create the GCS state bucket manually before running any Terraform command

### Requirement: complete-deployment-workflow
The README SHALL document the full lifecycle of the infrastructure: initial setup, apply, and destroy — including all manual steps that Terraform does not handle.

#### Scenario: First-time apply
- **WHEN** an engineer deploys the infrastructure for the first time
- **THEN** the README SHALL provide the exact commands in order: bucket creation, terraform init, terraform apply

#### Scenario: Destroy workflow
- **WHEN** an engineer needs to tear down the infrastructure
- **THEN** the README SHALL document the two-phase destroy pattern and explain why it is necessary

### Requirement: destroy-orchestration-documented
The README SHALL explain the destroy timing behavior and the two-phase pattern required to reliably delete the VPC after Cloud Run services are removed.

#### Scenario: Engineer understands why destroy takes 15-25 minutes
- **WHEN** an engineer runs terraform destroy for the first time
- **THEN** the README SHALL have already explained the GCP serverless IP reservation behavior and the time_sleep guards that handle it

#### Scenario: Engineer understands two-phase pattern
- **WHEN** terraform destroy fails with a subnet-in-use error
- **THEN** the README SHALL have documented the two-phase destroy approach as the recommended workaround

### Requirement: architecture-reference
The README SHALL provide an architecture overview covering the two-layer structure, key design decisions, and module inventory sufficient for an engineer to understand the system without reading every .tf file.

#### Scenario: Engineer understands layer separation
- **WHEN** an engineer reads the architecture section
- **THEN** they SHALL understand why foundation and workload are separate layers and what each owns

#### Scenario: Engineer can locate any module
- **WHEN** an engineer needs to find where a specific resource (e.g., Cloud Armor, Cloud SQL) is defined
- **THEN** the README SHALL provide a module inventory table mapping resource to module path

### Requirement: security-model-documented
The README SHALL summarize the defense-in-depth security model so reviewers and auditors can understand the security posture without reading the full Terraform code.

#### Scenario: Security reviewer understands WAF coverage
- **WHEN** a security reviewer reads the README
- **THEN** they SHALL find documentation that Cloud Armor is applied to both frontend and backend LB backend services

#### Scenario: Security reviewer understands ingress restrictions
- **WHEN** a security reviewer reads the README
- **THEN** they SHALL find documentation that both Cloud Run services reject direct *.run.app access and only accept traffic via the Load Balancer

### Requirement: troubleshooting-section
The README SHALL include a troubleshooting section covering the known GCP-specific failure modes that are not obvious from error messages alone.

#### Scenario: Engineer hits serverless IP reservation error
- **WHEN** an engineer sees "subnetwork resource is already being used by serverless-ipv4-*"
- **THEN** the troubleshooting section SHALL explain the cause (GCP async IP release, up to 120 min) and the resolution steps

#### Scenario: Engineer hits state lock error
- **WHEN** an engineer sees "Error acquiring the state lock"
- **THEN** the troubleshooting section SHALL provide the terraform force-unlock command with explanation
