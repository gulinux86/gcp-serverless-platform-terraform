## ADDED Requirements

### Requirement: core-directory-exclusion
The system MUST provide a `.gitignore` configuration that excludes the `openspec/changes/` directory to prevent local change artifacts from being committed.

#### Scenario: Verify changes directory ignore
- **WHEN** a new change is created in `openspec/changes/`
- **THEN** it MUST be ignored by `git status` (provided it's not already tracked).

### Requirement: ignore-pattern-standardization
The `.gitignore` SHOULD include patterns for temporary OpenSpec files, such as those in `.openspec/` or any generated log files.

#### Scenario: Verify temp file ignore
- **WHEN** a `.openspec` hidden directory is created
- **THEN** it MUST be ignored by version control.
