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

variable "connector_cidr" {
  description = "Dedicated /28 CIDR for the Serverless VPC Access Connector. Must not overlap the private subnets or the PSA range."
  type        = string
  default     = "10.8.0.0/28"
}

variable "connector_min_instances" {
  description = "Minimum number of connector instances (>= 2)."
  type        = number
  default     = 2
}

variable "connector_max_instances" {
  description = "Maximum number of connector instances (> min_instances)."
  type        = number
  default     = 3
}

variable "connector_machine_type" {
  description = "Machine type for the connector instances."
  type        = string
  default     = "e2-micro"
}
