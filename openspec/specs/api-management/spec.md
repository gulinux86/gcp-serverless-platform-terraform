## REMOVED Requirements

### Requirement: correct-openapi-schema
**Reason**: API Gateway is being removed to simplify the architecture. Managed API gateways add redundant complexity for the current service requirements.
**Migration**: Use the Global External Application Load Balancer for unified ingress and path-based routing.

### Requirement: functional-api-gateway-module
**Reason**: The module is being deleted from the codebase.
**Migration**: All service management logic should be handled directly by the backend services or at the Load Balancer level.
