## ADDED Requirements

### Requirement: blog-post-narrative
`docs/blog-post.md` SHALL be a long-form technical blog post (~1500-2500 words) covering the architecture design journey, targeted at GCP and Terraform practitioners.

#### Scenario: Practitioner gains actionable insight
- **WHEN** a GCP/Terraform practitioner reads the blog post
- **THEN** they SHALL learn at least one non-obvious technique or lesson they can apply to their own projects

### Requirement: blog-covers-key-topics
The blog post SHALL cover all of the following topics:
1. Why serverless-first (Cloud Run v2) over GKE for this workload
2. The two-layer architecture and dependency chain
3. The Cloud Armor security gap discovered (WAF only covering frontend) and the fix
4. Direct VPC Egress teardown choreography and the `time_sleep` pattern
5. At least one honest "lesson learned" or mistake made

#### Scenario: Key topics present
- **WHEN** the blog post is reviewed
- **THEN** all five topics SHALL be identifiable in the content

### Requirement: blog-post-tone
The blog post SHALL use a candid, first-person technical voice — honest about problems encountered, not a marketing piece.

#### Scenario: Tone is credible
- **WHEN** the blog post is read
- **THEN** it SHALL acknowledge real challenges and trade-offs, not only successes
