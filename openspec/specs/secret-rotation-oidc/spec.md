## ADDED Requirements

### Requirement: authenticated-push-subscription
The Pub/Sub push subscription for secret rotation MUST authenticate to the Cloud Run Job endpoint using an OIDC token so that GCP accepts the invocation request.

#### Scenario: Push subscription includes OIDC token
- **WHEN** Pub/Sub pushes a rotation event to the Cloud Run Job endpoint
- **THEN** the request SHALL include an OIDC identity token signed by a dedicated invoker service account

#### Scenario: Cloud Run Job accepts the push
- **WHEN** the push request arrives at the Cloud Run Jobs API with a valid OIDC token
- **THEN** the job SHALL be invoked successfully and return 2xx to Pub/Sub

#### Scenario: Unauthenticated push is rejected
- **WHEN** a push request arrives at the Cloud Run Job endpoint without a valid identity token
- **THEN** the request SHALL be rejected with 401 or 403

### Requirement: least-privilege-invoker-identity
A dedicated service account MUST be created solely for invoking the rotation handler job, with `roles/run.invoker` scoped to that specific job only.

#### Scenario: Invoker SA has no other permissions
- **WHEN** the invoker service account is used
- **THEN** it SHALL only have permission to invoke the single secret rotation Cloud Run Job, and no other GCP resources

#### Scenario: Invoker SA is internal to the rotation module
- **WHEN** the secret_rotation module is instantiated
- **THEN** the invoker service account SHALL be created and managed within the module without requiring callers to provide it
