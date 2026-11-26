variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "name" {
  type        = string
  description = "Human-readable name prefix for all GCP resources"
}

variable "environment" {
  type        = string
  description = "Environment name (hml, prod). Used in labels and display names."
}

variable "region" {
  type        = string
  description = "Default region"
  default     = "us-central1"
}

# --- Network ------------------------------------------------------------------

variable "node_subnet_cidr" {
  type        = string
  description = "Primary range of the node subnet."
}

variable "pods_cidr" {
  type        = string
  description = "Secondary range for pod IPs."
}

variable "services_cidr" {
  type        = string
  description = "Secondary range for Service ClusterIPs."
}

# --- Cluster ------------------------------------------------------------------

variable "cluster_location" {
  type        = string
  description = "Region (regional control plane, for prod) or zone (zonal, covered by the GKE free tier — fine for hml)."
}

variable "release_channel" {
  type        = string
  description = "GKE release channel."
  default     = "REGULAR"
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "Internal CIDRs allowed on the private IP endpoint. External access (CI, operators) uses the IAM-authorised DNS endpoint."
  default     = []
}

variable "deletion_protection" {
  type        = bool
  description = "Block destroying the cluster. Off in hml, which is torn down routinely."
}

# --- Node pool ----------------------------------------------------------------

variable "node_machine_type" {
  type        = string
  description = "Machine type of the default node pool."
}

variable "node_spot" {
  type        = bool
  description = "Use Spot VMs for the default node pool."
}

variable "node_min_count" {
  type        = number
  description = "Autoscaler minimum per zone."
}

variable "node_max_count" {
  type        = number
  description = "Autoscaler maximum per zone."
}
