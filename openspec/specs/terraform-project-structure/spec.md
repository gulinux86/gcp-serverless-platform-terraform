## ADDED Requirements

### Requirement: structural-hygiene
The project structure MUST include a `.gitignore` at the root (or specific subdirectory) that correctly identifies and excludes non-permanent configuration artifacts.

#### Scenario: Verify gitignore presence
- **WHEN** the project root is inspected
- **THEN** a `.gitignore` file MUST exist and contain OpenSpec-specific exclusion rules.

### Requirement: modular-layer-separation
The Terraform project MUST be organized into distinct `foundation` and `workload` layers to separate infrastructure lifecycle management.

#### Scenario: Verify Directory Structure
- **WHEN** the project root is inspected
- **THEN** it MUST contain `foundation` and `workload` modules.
- **AND** it MUST NOT contain any local state files (`.tfstate`) in permanent tracking.

### Requirement: inter-layer-handshake
The root module SHALL orchestrate the communication between layers by passing the outputs of the `foundation` layer as inputs to the `workload` layer. The root module MUST also accept a `var.name` input that is propagated to both layers as the canonical resource naming prefix.

#### Scenario: root-main-tf-verification
- **WHEN** the root `main.tf` is reviewed
- **THEN** it MUST show the `workload` module consuming attributes (including DNS zone names) from the `foundation` module
- **AND** both `module.foundation` and `module.workload` MUST receive a `name` variable

#### Scenario: resource-naming-convention
- **WHEN** any GCP resource is provisioned by this project
- **THEN** its name MUST use `var.name` as a prefix (e.g. `{name}-vpc`, `{name}-db`)
- **AND** it MUST NOT use the GCP project ID as a name prefix
