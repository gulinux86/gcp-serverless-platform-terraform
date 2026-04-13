## ADDED Requirements

### Requirement: rotation-event-subscriber
The secret rotation Pub/Sub topic SHALL have an active subscriber so that rotation notification events are consumed and acknowledged, completing the rotation lifecycle rather than being silently dropped.

The subscriber MUST authenticate to the Cloud Run Job endpoint using an OIDC token issued by a dedicated invoker service account.

#### Scenario: Rotation event is consumed
- **WHEN** Secret Manager publishes a rotation notification to the Pub/Sub topic
- **THEN** the subscriber SHALL receive and acknowledge the message within the topic's acknowledgement deadline

#### Scenario: Subscriber is a Cloud Run Job
- **WHEN** a rotation event is received
- **THEN** a Cloud Run Job SHALL be invoked via Pub/Sub push subscription to handle the event

#### Scenario: Invocation is authenticated
- **WHEN** the push subscription delivers a rotation event to the Cloud Run Job endpoint
- **THEN** the delivery SHALL include a valid OIDC identity token so the job endpoint accepts the request
