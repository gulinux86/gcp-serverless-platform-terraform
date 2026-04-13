## ADDED Requirements

### Requirement: frontend-as-compute
The frontend application MUST be deployed as a Cloud Run service named `frontend`, allowing for dynamic rendering and consistent compute management.

#### Scenario: Provision Frontend Service
- **WHEN** the workload layer is applied
- **THEN** a Cloud Run service named `frontend` MUST be provisioned.

### Requirement: restricted-direct-access
The frontend Cloud Run service SHOULD be configured to only allow traffic from the Global Load Balancer.

#### Scenario: Direct Access Check
- **WHEN** a user tries to access the Cloud Run `.run.app` URL directly
- **THEN** it SHOULD be restricted or discouraged in favor of the Load Balancer URL.
