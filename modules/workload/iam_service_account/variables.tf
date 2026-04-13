variable "account_id" {
  description = "Service account ID (the part of the email before @)"
  type        = string
}

variable "display_name" {
  description = "Service account display name"
  type        = string
  default     = ""
}

variable "description" {
  description = "Service account description"
  type        = string
  default     = "Service account managed by Terraform"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "create_key" {
  description = "Create service account key"
  type        = bool
  default     = false
}

variable "public_key_type" {
  description = "Public key type (TYPE_X509_PEM_FILE or TYPE_RAW_PUBLIC_KEY)"
  type        = string
  default     = "TYPE_X509_PEM_FILE"
}

variable "iam_roles" {
  description = "Map of IAM roles to assign to the service account in the project"
  type        = map(string)
  default     = {}
}

variable "service_account_iam_roles" {
  description = "Map of members and roles for the service account's own IAM"
  type        = map(string)
  default     = {}
}
