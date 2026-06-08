# security_policy.tftest.hcl
#
# Trade-off context:
#   mock_provider + command=plan → zero GCP cost, runs in seconds, no credentials.
#   The downside: we can't validate that GCP actually accepts the rule expressions
#   (e.g. 'evaluatePreconfiguredExpr' is a GCP-side evaluation). What we CAN catch
#   is accidental deletion of rules, wrong actions, or broken rate limit config —
#   the regressions that actually happen during refactors.

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "test-app"
}

run "waf_deny_rules_always_present" {
  command = plan

  assert {
    condition = length([
      for rule in google_compute_security_policy.this.rule
      : rule if rule.action == "deny(403)"
    ]) >= 2
    error_message = "Must have at least 2 deny(403) rules. XSS (priority 1000) and SQL injection (priority 1001) protection cannot be removed."
  }
}

run "xss_rule_at_correct_priority" {
  command = plan

  assert {
    condition = length([
      for rule in google_compute_security_policy.this.rule
      : rule if rule.action == "deny(403)" && rule.priority == 1000
    ]) == 1
    error_message = "XSS protection rule must exist at priority 1000. Changing priority can cause rule shadowing."
  }
}

run "sqli_rule_at_correct_priority" {
  command = plan

  assert {
    condition = length([
      for rule in google_compute_security_policy.this.rule
      : rule if rule.action == "deny(403)" && rule.priority == 1001
    ]) == 1
    error_message = "SQL injection protection rule must exist at priority 1001. Changing priority can cause rule shadowing."
  }
}

run "rate_limiting_rule_always_present" {
  command = plan

  assert {
    condition = length([
      for rule in google_compute_security_policy.this.rule
      : rule if rule.action == "throttle"
    ]) == 1
    error_message = "Rate limiting rule must always be present to protect against volumetric attacks."
  }
}

run "ddos_adaptive_protection_enabled" {
  command = plan

  assert {
    condition     = google_compute_security_policy.this.adaptive_protection_config[0].layer_7_ddos_defense_config[0].enable == true
    error_message = "Layer 7 DDoS adaptive protection must always be enabled. This cannot be opt-out."
  }
}

run "policy_name_follows_convention" {
  command = plan

  assert {
    condition     = google_compute_security_policy.this.name == "test-app-policy"
    error_message = "Security policy name must follow the '<name>-policy' pattern for consistent resource identification."
  }
}

run "custom_rate_limit_threshold_applied" {
  command = plan

  variables {
    rate_limit_threshold = 50
  }

  assert {
    # try() guards the index: rules without rate_limit_options (XSS/SQLi/allow)
    # yield null instead of erroring. Indexing inside the `if` condition is
    # evaluated for every rule, so a blind [0] fails on rules with no rate limit.
    condition = length([
      for rule in google_compute_security_policy.this.rule
      : true
      if try(rule.rate_limit_options[0].rate_limit_threshold[0].count, null) == 50
    ]) == 1
    error_message = "Custom rate_limit_threshold must be reflected in the throttle rule. Default (100) would leave the custom value silently ignored."
  }
}
