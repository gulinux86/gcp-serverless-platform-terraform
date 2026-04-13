## ADDED Requirements

### Requirement: unified-serverless-compute
The system MUST use Cloud Run for all compute needs, separating interactive workloads (`frontend`, `backend`).

#### Scenario: API Deployment
- **WHEN** the workload layer is applied
- **THEN** a Cloud Run Service named `backend` MUST be provisioned.

#### Scenario: Frontend Deployment
- **WHEN** the workload layer is applied
- **THEN** a Cloud Run Service named `frontend` MUST be provisioned.

### Requirement: managed-data-persistence
The system MUST utilize managed GCP services for state and data, specifically Cloud SQL for relational data and GCS for object storage.

#### Scenario: SQL Connectivity
- **WHEN** the workload layer is applied
- **THEN** a Cloud SQL instance MUST be available and connected via private IP.
