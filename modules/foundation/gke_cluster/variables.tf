variable "name" {
  description = "Cluster name."
  type        = string
}

variable "project_id" {
  description = "GCP project ID. Also names the Workload Identity pool (<project>.svc.id.goog)."
  type        = string
}

variable "location" {
  description = "A region (regional cluster: control plane replicated across three zones) or a zone (zonal cluster: one control plane replica, covered by the GKE free tier). Use a region for production."
  type        = string
}

variable "network_id" {
  description = "VPC network ID."
  type        = string
}

variable "subnet_id" {
  description = "Node subnet ID. Must carry the two secondary ranges named below."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet's secondary range for pod IPs."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet's secondary range for Service ClusterIPs."
  type        = string
}

variable "release_channel" {
  description = "GKE release channel. The channel drives control-plane and node upgrades inside the maintenance window."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR or STABLE."
  }
}

variable "master_authorized_networks" {
  description = "Internal CIDRs allowed to reach the private IP endpoint (e.g. a VPN range). Access from outside the VPC uses the IAM-authorised DNS endpoint and needs no entry here."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "binary_authorization_mode" {
  description = "DISABLED, or PROJECT_SINGLETON_POLICY_ENFORCE to admit only images the project's Binary Authorization policy allows. Turn on once the image pipeline signs/attests images."
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["DISABLED", "PROJECT_SINGLETON_POLICY_ENFORCE"], var.binary_authorization_mode)
    error_message = "binary_authorization_mode must be DISABLED or PROJECT_SINGLETON_POLICY_ENFORCE."
  }
}

variable "maintenance_start_time" {
  description = "Start of the recurring maintenance window (RFC 3339)."
  type        = string
  default     = "2026-01-03T03:00:00Z"
}

variable "maintenance_end_time" {
  description = "End of the recurring maintenance window (RFC 3339). Only the time-of-day and duration matter."
  type        = string
  default     = "2026-01-03T09:00:00Z"
}

variable "maintenance_recurrence" {
  description = "RFC 5545 RRULE for the maintenance window."
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "labels" {
  description = "Resource labels applied to the cluster."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Block `terraform destroy` of the cluster. On in production; off where the environment is torn down routinely."
  type        = bool
  default     = true
}
