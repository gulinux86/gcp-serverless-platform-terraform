variable "name" {
  description = "Base name prefix for VPC and subnet resources. For example, 'app' produces 'app-vpc' and 'app-vpc-private'."
  type        = string
}

variable "region" {
  description = "GCP region for subnet and PSA range creation. Must match the region of the GKE cluster and Cloud SQL instance that connect to this network."
  type        = string
  default     = "us-central1"
}

variable "routing_mode" {
  description = "Routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "GLOBAL"
}

variable "private_subnet_cidr" {
  description = "Primary range of the node subnet. Each GKE node takes one address from here."
  type        = string
  default     = "10.0.0.0/22"
}

variable "pods_cidr" {
  description = "Secondary range for pod IPs (VPC-native alias IPs). Must not overlap the primary range, the Service range or the PSA range."
  type        = string
  default     = "10.4.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for Kubernetes Service ClusterIPs. Must not overlap the primary range, the pod range or the PSA range."
  type        = string
  default     = "10.8.0.0/20"
}

variable "log_aggregation_interval" {
  description = "VPC flow log aggregation interval. Valid values: INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN, INTERVAL_15_MIN."
  type        = string
  default     = "INTERVAL_5_SEC"
}

variable "log_flow_sampling" {
  description = "Log flow sampling rate (0.0 to 1.0)"
  type        = number
  default     = 0.5
}
