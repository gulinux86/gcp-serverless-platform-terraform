## ADDED Requirements

### Requirement: gcs-remote-backend
All Terraform project layers (root, foundation, workload) MUST use a GCS bucket for state storage to ensure safety and collaboration.

#### Scenario: Verify Backend Configuration
- **WHEN** the `version.tf` file of any layer is inspected
- **THEN** it MUST contain a `backend "gcs"` block.

### Requirement: state-bucket-provisioning
A dedicated, versioned GCS bucket MUST be provisioned to hold the Terraform state files.

#### Scenario: Verify Bucket Versioning
- **WHEN** the Terraform state bucket is inspected
- **THEN** object versioning MUST be enabled to allow state recovery.
