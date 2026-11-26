terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # 2.x: the `set {}` block syntax below. Helm provider 3.x replaced it with a
    # list attribute, so a major bump is a code change, not a version change.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}
