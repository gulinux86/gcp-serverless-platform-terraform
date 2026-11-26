variable "name" {
  description = "Node pool name."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "cluster_id" {
  description = "ID of the cluster this pool belongs to."
  type        = string
}

variable "location" {
  description = "Cluster location (region or zone). Must match the cluster's."
  type        = string
}

variable "node_locations" {
  description = "Zones to place nodes in. Empty uses the cluster's zones."
  type        = list(string)
  default     = []
}

variable "machine_type" {
  description = "Compute Engine machine type for the nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Boot disk size per node, in GB."
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Boot disk type: pd-standard, pd-balanced or pd-ssd."
  type        = string
  default     = "pd-balanced"
}

variable "spot" {
  description = "Run on Spot VMs: much cheaper, preemptible at any time. Fine for hml; keep production on on-demand capacity."
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Autoscaler minimum, per zone."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Autoscaler maximum, per zone."
  type        = number
  default     = 3

  validation {
    condition     = var.max_node_count >= 1
    error_message = "max_node_count must be at least 1."
  }
}

variable "service_account_email" {
  description = "Dedicated node service account. Must not be the Compute Engine default SA."
  type        = string

  validation {
    condition     = !endswith(var.service_account_email, "-compute@developer.gserviceaccount.com")
    error_message = "Use a dedicated node service account, not the Compute Engine default SA (it holds roles/editor)."
  }
}

variable "labels" {
  description = "Kubernetes labels applied to every node."
  type        = map(string)
  default     = {}
}

variable "network_tags" {
  description = "Network tags on the node VMs, for firewall targeting."
  type        = list(string)
  default     = []
}

variable "taints" {
  description = "Kubernetes taints applied to every node."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}
