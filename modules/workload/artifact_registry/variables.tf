variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
}

variable "location" {
  description = "Repository location"
  type        = string
  default     = "us-central1"
}

variable "format" {
  description = "Repository format. Determines what package types the repository stores. Valid values: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, KFP, GO."
  type        = string
  default     = "DOCKER"

  validation {
    condition     = contains(["DOCKER", "MAVEN", "NPM", "PYTHON", "APT", "YUM", "KFP", "GO"], var.format)
    error_message = "format must be one of: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, KFP, GO."
  }
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Managed by Terraform"
}

variable "labels" {
  description = "Repository labels"
  type        = map(string)
  default     = {}
}
