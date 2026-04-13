variable "name" {
  description = "Base name prefix for VPC and subnet resources. For example, 'app' produces 'app-vpc' and 'app-vpc-private'."
  type        = string
}

variable "region" {
  description = "GCP region for subnet and PSA range creation. Must match the region of workload resources (Cloud Run, Cloud SQL) that connect to this network."
  type        = string
  default     = "us-central1"
}

variable "routing_mode" {
  description = "Routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "GLOBAL"
}

variable "private_subnet_cidr" {
  description = "Primary private subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "secondary_subnet_cidr" {
  description = "Secondary private subnet CIDR (must not overlap with primary or PSA range)"
  type        = string
  default     = "10.0.3.0/24"
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

variable "serverless_decommission_signal" {
  type        = map(string)
  description = "Signal from the workload layer indicating serverless IP cooldowns are complete. When provided, the private subnetwork will depend on it to enforce correct destruction ordering."
  default     = null
  nullable    = true
}
