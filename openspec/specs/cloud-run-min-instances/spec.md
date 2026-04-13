## ADDED Requirements

### Requirement: minimum-instance-guarantee
Cloud Run services SHALL support a configurable minimum instance count to keep at least one instance warm, eliminating cold starts for user-facing and internal services.

#### Scenario: No cold start on first request after idle
- **WHEN** `min_instance_count` is set to 1 or greater
- **THEN** Cloud Run SHALL maintain at least that many instances running at all times, so the first request after an idle period SHALL NOT incur a cold start delay

#### Scenario: Default is zero for dev environments
- **WHEN** `min_instance_count` is not explicitly set
- **THEN** it SHALL default to `0` so development environments scale to zero and incur no idle cost
