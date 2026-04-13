terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "project-ccb8f609-7f01-4720-8cf-terraform-state"
    prefix = "root"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
