## ADDED Requirements

### Requirement: secondary-private-subnet
The VPC module SHALL provision a second private subnet with an independently configurable CIDR, enabling workload traffic isolation within the same VPC network.

#### Scenario: Secondary subnet deployment
- **WHEN** the foundation layer is applied
- **THEN** a second `google_compute_subnetwork` SHALL be created in the same region as the primary subnet, with Private Google Access enabled and flow logs configured.

#### Scenario: Non-overlapping CIDRs
- **WHEN** both subnets are provisioned
- **THEN** each subnet MUST have a distinct, non-overlapping CIDR range (default: primary `10.0.2.0/24`, secondary `10.0.3.0/24`).

#### Scenario: Secondary subnet outputs available
- **WHEN** the foundation layer is applied
- **THEN** `secondary_subnet_id` and `secondary_subnet_name` SHALL be available as outputs for workload modules to reference.

### Requirement: secondary-subnet-destruction-ordering
The secondary subnet SHALL respect the same destruction-ordering constraints as the primary subnet to prevent "Resource in use" errors.

#### Scenario: Destruction after workload cooldown
- **WHEN** the foundation layer is destroyed
- **THEN** the secondary subnet SHALL only be deleted after the workload decommission signal is complete and the PSA decommissioning buffer has elapsed.
