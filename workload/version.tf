terraform {
  required_version = ">= 1.7.0"

  # Partial backend: bucket + prefix are supplied at init time via
  # -backend-config=environments/<env>/backend.hcl (per-environment state).
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.14.0"
    }
    # Used transitively by the cloud_sql module (time_sleep).
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    # Argo CD and its bootstrap chart. 2.x for the `set {}` block syntax.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}
