## ADDED Requirements

### Requirement: foundation-network-id-export
The foundation module MUST export the unique resource IDs for the VPC network and the associated subnets.

#### Scenario: Verify network_id output
- **WHEN** the foundation layer is applied
- **THEN** it MUST provide a `vpc_network_id` and `private_subnet_id` as outputs.

### Requirement: workload-network-id-consumption
The workload module MUST accept the network and subnet IDs as input variables to configure resource-level connectivity.

#### Scenario: Resource binding
- **WHEN** Cloud Run or Cloud SQL are provisioned in the workload layer
- **THEN** they MUST be associated with the IDs provided by the foundation layer.
