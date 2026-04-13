## ADDED Requirements

### Requirement: multi-backend-routing
The Load Balancer MUST support routing traffic to multiple independent Cloud Run services based on the request path.

#### Scenario: Route to Backend API
- **WHEN** a request arrives with the path prefix `/api`
- **THEN** the Load Balancer MUST route the traffic to the Backend Cloud Run service.

#### Scenario: Route to Frontend
- **WHEN** a request arrives with any other path (default)
- **THEN** the Load Balancer MUST route the traffic to the Frontend Cloud Run service.

### Requirement: unified-security-policy
A single Cloud Armor security policy MUST be applicable across all serverless backends managed by the Load Balancer.

#### Scenario: Apply WAF rules
- **WHEN** security rules are defined
- **THEN** they MUST be enforced for both frontend and backend traffic.

### Requirement: http-proxy-uses-path-routing
When path-based routing is configured (i.e., `api_cloud_run_service_name` is set), the HTTP target proxy SHALL route through the path-based URL map regardless of whether a domain (TLS) is configured. The redirect URL map SHALL only be used by the HTTP proxy when a domain is set and its sole purpose is to redirect HTTP to HTTPS.

#### Scenario: HTTP request to /api/* routed to backend (no domain)
- **WHEN** `api_cloud_run_service_name` is set and `domain` is null
- **THEN** an HTTP request to `/api/<path>` SHALL be routed to the API backend Cloud Run service

#### Scenario: HTTP request to / routed to frontend (no domain)
- **WHEN** `api_cloud_run_service_name` is set and `domain` is null
- **THEN** an HTTP request to `/` SHALL be routed to the frontend Cloud Run service

#### Scenario: HTTP redirects to HTTPS when domain is set
- **WHEN** `domain` is set and a client makes an HTTP request
- **THEN** the HTTP proxy SHALL redirect the request to HTTPS (301)
