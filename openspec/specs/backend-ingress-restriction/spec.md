## MODIFIED Requirements

### Requirement: internal-only-backend-ingress
The backend Cloud Run service MUST only accept traffic originating from the Global HTTPS Load Balancer, preventing direct external access that bypasses Cloud Armor. The ingress mode SHALL be set to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`. The `cloud_run_service` module's `ingress` variable SHALL default to `INGRESS_TRAFFIC_INTERNAL_ONLY` so that any new service is private unless explicitly configured otherwise.

#### Scenario: External request is rejected
- **WHEN** a request is made directly to the backend Cloud Run URL from outside the VPC (e.g., via `*.run.app`)
- **THEN** the request SHALL be rejected with HTTP 403 before reaching the service

#### Scenario: LB-routed request is accepted
- **WHEN** the Global HTTPS Load Balancer routes an `/api/*` request to the backend via Serverless NEG
- **THEN** the backend SHALL receive and process the request normally

#### Scenario: Safe default for new services
- **WHEN** a new Cloud Run service module call omits the `ingress` variable
- **THEN** the service SHALL default to `INGRESS_TRAFFIC_INTERNAL_ONLY`, blocking all external access unless explicitly overridden
