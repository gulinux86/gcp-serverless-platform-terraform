## ADDED Requirements

### Requirement: component-specific-service-accounts
Every functional component (e.g., Backend API, Async Job) MUST have its own dedicated IAM Service Account.

#### Scenario: Verify Backend SA
- **WHEN** the backend API is deployed
- **THEN** it MUST be configured with a unique service account (e.g., `backend-api-sa`).

### Requirement: granular-role-assignment
Service accounts SHALL be assigned only the minimum roles required for their operation (e.g., `roles/run.invoker` for services, `roles/storage.objectViewer` for read-only access). Sensitive credentials used at runtime MUST be stored in Secret Manager and accessed via secret references rather than passed as plain-text environment variables.

#### Scenario: Read-only access
- **WHEN** a service only needs to read from a bucket
- **THEN** it MUST NOT have `roles/storage.objectAdmin` or equivalent write permissions.

#### Scenario: Database credential handling
- **WHEN** a service requires a database password at runtime
- **THEN** the password MUST be stored as a Secret Manager secret and injected via a secret reference, not embedded as a plain-text environment variable.

### Requirement: backend-service-access-restriction
Internal services (services not intended for direct end-user access) SHALL require authentication for all invocations.

#### Scenario: Backend API is not publicly accessible
- **WHEN** the backend Cloud Run service is deployed
- **THEN** it SHALL NOT allow unauthenticated invocations (i.e., `roles/run.invoker` for `allUsers` MUST NOT be granted).

#### Scenario: Frontend can invoke backend
- **WHEN** the frontend service calls the backend API
- **THEN** the request SHALL be authenticated using the frontend service account's identity token.

## MODIFIED Requirements

### Requirement: secret-accessor-scope
The `roles/secretmanager.secretAccessor` role for Cloud Run service accounts SHALL be bound at the individual secret resource level, not at the project level. Each service account SHALL be granted access only to the specific secrets it needs at runtime.

#### Scenario: Backend SA can only read its own secrets
- **WHEN** the backend service account attempts to access a Secret Manager secret it has not been explicitly granted access to
- **THEN** the access SHALL be denied with a permission error

#### Scenario: Per-secret IAM binding is provisioned
- **WHEN** a Cloud Run service requires access to a specific secret
- **THEN** a `google_secret_manager_secret_iam_member` resource SHALL be created granting that service account `roles/secretmanager.secretAccessor` on that specific secret only
