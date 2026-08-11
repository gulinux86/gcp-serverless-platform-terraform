terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    # time_sleep.wait_for_ip_release — Direct VPC Egress IP-release cooldown.
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
