## ADDED Requirements

### Requirement: code-formatting-compliance
All Terraform files (`.tf`) MUST comply with the standard `terraform fmt` style rules to ensure a consistent and readable codebase.

#### Scenario: Recursive Formatting
- **WHEN** the formatting task is executed
- **THEN** all `.tf` files in the project root and subdirectories MUST be updated to match standard formatting.

### Requirement: configuration-validity
The Terraform configuration MUST be syntactically correct and internally consistent across all managed layers.

#### Scenario: Layer Validation
- **WHEN** `terraform validate` is run in any configuration directory
- **THEN** it MUST return a success message indicating the configuration is valid.

### Requirement: actionable-execution-plan
The system MUST be capable of generating a valid execution plan that details the proposed infrastructure changes.

#### Scenario: Generate Plan
- **WHEN** `terraform plan` is executed with the required variables
- **THEN** it MUST produce a summary of resources to be added, changed, or destroyed.
