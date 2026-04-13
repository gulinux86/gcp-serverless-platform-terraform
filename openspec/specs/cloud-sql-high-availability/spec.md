## ADDED Requirements

### Requirement: regional-ha-failover
The Cloud SQL instance SHALL be configurable for regional high availability (`availability_type = "REGIONAL"`), enabling automatic failover to a standby instance in a secondary zone within the same region.

#### Scenario: Failover on primary zone outage
- **WHEN** the primary Cloud SQL zone experiences an outage
- **THEN** the standby instance SHALL become the primary automatically without manual intervention

#### Scenario: HA disabled by default for non-production
- **WHEN** `availability_type` is not explicitly set
- **THEN** it SHALL default to `"ZONAL"` so development environments do not incur HA costs
