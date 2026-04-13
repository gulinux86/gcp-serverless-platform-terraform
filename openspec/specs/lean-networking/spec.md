## ADDED Requirements

### Requirement: internal-only-vpc
The system SHALL maintain a VPC architecture that is internal-only by default, removing all public subnets and NAT Gateways, and ensuring that all managed resource associations (IPs, peerings) are released before core network destruction. All firewall rules MUST restrict source ranges to private CIDR blocks only. The VPC MUST support at least two private subnets to allow workload traffic isolation.

#### Scenario: VPC Deployment
- **WHEN** the foundation layer is applied
- **THEN** exactly one VPC network SHALL be created with no public-facing subnets and at least two private subnets.

#### Scenario: VPC Destruction
- **WHEN** the foundation layer is destroyed
- **THEN** the system SHALL observe a 10-minute cooldown period to ensure all Google-managed serverless IP reservations (e.g., serverless-ipv4) are released before subnetwork deletion.

#### Scenario: Reliable VPC Destruction
- **WHEN** the foundation layer is destroyed
- **THEN** resources SHALL be removed in a linear sequence (Service Peering -> IP Range -> Subnetwork -> Network) to prevent "Resource in use" errors.

#### Scenario: Firewall source range restriction
- **WHEN** a firewall allow-rule is created in the internal VPC
- **THEN** its source ranges MUST be restricted to private CIDR ranges (e.g., `10.0.0.0/8`) and MUST NOT include `0.0.0.0/0`.

### Requirement: direct-vpc-egress-connectivity
The system SHALL use Direct VPC Egress for all serverless compute resources to communicate with the VPC.

#### Scenario: Cloud Run Egress
- **WHEN** a Cloud Run service is provisioned
- **THEN** it SHALL be configured with a Direct VPC Egress `network_interface` pointing to the private subnet.

### Requirement: google-api-private-access
The system SHALL enable Private Google Access on all subnets to allow communication with Google Cloud APIs without requiring a NAT Gateway.

#### Scenario: External API Call (GCP)
- **WHEN** a service calls a Google API (e.g., Secret Manager)
- **THEN** the request SHALL succeed via Private Google Access over the internal VPC network.

### Requirement: serverless-ip-release-buffer
The system SHALL enforce a mandatory cooldown period after serverless compute resources are destroyed to allow for IP address release. This cooldown SHALL be enforced at both the per-service level and the workload layer to guarantee coverage regardless of per-service timer state.

#### Scenario: Per-service destruction cooldown
- **WHEN** a Cloud Run service is marked for deletion
- **THEN** a delay of at least 150 seconds SHALL be observed after deletion and before the service's module signals completion

#### Scenario: Workload-layer destruction cooldown
- **WHEN** all Cloud Run services in the workload module are deleted
- **THEN** a delay of at least 150 seconds SHALL be enforced at the workload layer before the workload module completes teardown

### Requirement: managed-peering-release-buffer
The system SHALL enforce a delay before deleting the Private Service Access peering to prevent "Producer services in use" errors.

#### Scenario: Peering destruction
- **WHEN** the Service Networking connection is marked for deletion
- **THEN** a delay of 600 seconds SHALL be enforced to allow backend cleanup.

### Requirement: mandatory-decommissioning-cooldown
The system SHALL observe a mandatory cooldown period during infrastructure destruction to allow Google-managed control planes to release resource locks.

#### Scenario: Trigger destruction cooldown
- **WHEN** a `terraform destroy` is initiated
- **THEN** a 600-second pause SHALL occur after consumer resources (Cloud Run, Cloud SQL) are deleted and before the Service Networking connection is removed.

## MODIFIED Requirements

### Requirement: internal-firewall-rules
The VPC firewall SHALL restrict internal traffic to only the ports required by the running workloads. Port 80 (HTTP) SHALL NOT be permitted internally since all plaintext HTTP is handled at the LB edge via redirect; internal services communicate only over HTTPS (443) and the application port (8080).

#### Scenario: Port 80 is not open internally
- **WHEN** an internal resource attempts to connect to another resource on port 80
- **THEN** the firewall SHALL deny the connection

#### Scenario: HTTPS and app port remain open
- **WHEN** an internal resource connects on port 443 or 8080 from an RFC1918 address
- **THEN** the firewall SHALL allow the connection
