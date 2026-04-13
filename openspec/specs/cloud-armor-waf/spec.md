## MODIFIED Requirements

### Requirement: cloud-armor-security-policy
The Cloud Armor security policy SHALL be provisioned in its own dedicated Terraform module (`modules/workload/cloud_armor/`) containing only the `google_compute_security_policy` resource and its rules. Load balancing resources (NEG, backend service, URL map, proxy, SSL certificate, forwarding rule) SHALL reside in a separate module (`modules/workload/https_load_balancer/`). The security policy SHALL be passed to the load balancer module as an input, maintaining the WAF → LB → Cloud Run chain.

The security policy SHALL also enable Adaptive Protection with Layer 7 DDoS defense to detect and mitigate volumetric attacks that do not match static preconfigured rules.

#### Scenario: WAF blocks OWASP Top 10 attacks
- **WHEN** a request matching an OWASP managed rule (e.g., SQLi, XSS) reaches the load balancer
- **THEN** Cloud Armor SHALL deny the request with HTTP 403 before it reaches Cloud Run

#### Scenario: Rate limiting blocks volumetric abuse
- **WHEN** a single IP exceeds the configured request rate threshold
- **THEN** Cloud Armor SHALL throttle or block subsequent requests from that IP

#### Scenario: Adaptive Protection detects anomalous traffic
- **WHEN** traffic patterns deviate significantly from the established baseline (ML-detected DDoS)
- **THEN** Cloud Armor Adaptive Protection SHALL generate a suggested rule and optionally auto-mitigate the attack

### Requirement: lb-fronted-frontend-ingress
The frontend Cloud Run service SHALL only accept traffic originating from the Global HTTPS Load Balancer, provisioned via `modules/workload/https_load_balancer/`. Direct calls to the `*.run.app` URL SHALL be rejected.

#### Scenario: Direct run.app URL is blocked
- **WHEN** a client calls the frontend Cloud Run service directly via its `*.run.app` URL
- **THEN** the service SHALL return HTTP 403 (ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER)

#### Scenario: LB traffic is accepted
- **WHEN** a client calls the frontend via the load balancer forwarding rule IP or custom domain
- **THEN** the request SHALL reach the Cloud Run service and receive a valid response

### Requirement: managed-ssl-termination
The Global HTTPS Load Balancer (`modules/workload/https_load_balancer/`) SHALL terminate TLS using a Google-managed SSL certificate, enabling HTTPS for the frontend without manual certificate rotation.

#### Scenario: HTTPS enforced at the load balancer
- **WHEN** a client connects to the frontend via the load balancer
- **THEN** the connection SHALL be TLS-encrypted using a Google-managed certificate
