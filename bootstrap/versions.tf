terraform {
  required_version = ">= 1.7.0"

  # Local state on purpose: bootstrap is a one-time, human-run config (it creates
  # the keyless-auth plumbing that CI itself depends on, so it cannot run in CI).
  # Run it once per environment with elevated/owner credentials.

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}
