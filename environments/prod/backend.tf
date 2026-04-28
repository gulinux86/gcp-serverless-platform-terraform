terraform {
  required_version = ">= 1.5.0"

  # Bootstrap the PROD state bucket BEFORE running terraform init:
  #   gcloud storage buckets create gs://<prod-project-id>-terraform-state \
  #     --location=US-CENTRAL1 --uniform-bucket-level-access --project=<prod-project-id>
  #   gcloud storage buckets update gs://<prod-project-id>-terraform-state --versioning
  # Replace <prod-project-id> with your actual PROD project ID.
  backend "gcs" {
    bucket = "<prod-project-id>-terraform-state"
    prefix = "prod"
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

provider "google" {
  project = var.project_id
  region  = var.region
}
