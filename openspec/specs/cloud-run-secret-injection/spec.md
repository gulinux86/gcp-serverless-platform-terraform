## ADDED Requirements

### Requirement: secret-backed-env-vars
Cloud Run services SHALL inject sensitive runtime values (e.g., database passwords, API tokens) from Secret Manager using native secret references rather than plain-text environment variables.

#### Scenario: Secret injection at service deployment
- **WHEN** a Cloud Run service is deployed with a secret-backed environment variable
- **THEN** the secret value SHALL be sourced from a Secret Manager secret version and SHALL NOT appear as a plain-text value in the service's environment variable configuration.

#### Scenario: Secret access by service account
- **WHEN** a Cloud Run service accesses an injected secret at runtime
- **THEN** the service's service account MUST have `roles/secretmanager.secretAccessor` on the referenced secret.

### Requirement: no-plaintext-credentials-in-env
Cloud Run service environment variables MUST NOT contain plain-text passwords, private keys, or other credentials.

#### Scenario: Database password handling
- **WHEN** a Cloud Run service requires a database password
- **THEN** the password SHALL be injected via a Secret Manager secret reference, not as a plain-text `DATABASE_URL` or `DB_PASSWORD` env var value.
