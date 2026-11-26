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

variable "workload_identity_ksas" {
  description = "Kubernetes service accounts, as \"<namespace>/<name>\", allowed to impersonate this SA through GKE Workload Identity."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for k in var.workload_identity_ksas : can(regex("^[a-z0-9-]+/[a-z0-9-]+$", k))])
    error_message = "Each entry must be \"<namespace>/<ksa-name>\"."
  }
}

variable "workload_identity_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog). Required when workload_identity_ksas is set."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.workload_identity_pool == null || can(regex("\\.svc\\.id\\.goog$", var.workload_identity_pool))
    error_message = "workload_identity_pool must look like <project>.svc.id.goog."
  }
}
