## ADDED Requirements

### Requirement: http-redirect-to-https
The Global HTTPS Load Balancer SHALL redirect all HTTP requests on port 80 to HTTPS with a 301 Moved Permanently response, ensuring no client can reach the application over plaintext.

#### Scenario: HTTP request is redirected
- **WHEN** a client sends an HTTP request to port 80 on the load balancer IP or domain
- **THEN** the load balancer SHALL respond with HTTP 301 and a `Location` header pointing to the same URL with `https://` scheme

#### Scenario: HTTPS request is unaffected
- **WHEN** a client sends an HTTPS request to port 443
- **THEN** the request SHALL proceed normally through the existing LB pipeline without any redirect
