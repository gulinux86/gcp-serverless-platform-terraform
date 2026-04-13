variable "name" {
  description = "Unique name for the Cloud SQL instance. Used as the GCP resource ID and must be unique within the project."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud SQL instance. Must match the VPC region for Private Service Access (PSA) connectivity."
  type        = string
  default     = "us-central1"
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Instance tier (e.g., db-f1-micro, db-n1-standard-1)"
  type        = string
  default     = "db-f1-micro"
}

variable "database_name" {
  description = "Name of the initial database to create inside the Cloud SQL instance."
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Username for the initial database user created on the instance."
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "availability_type" {
  description = "High availability mode. REGIONAL provisions a standby replica in a different zone with automatic failover. ZONAL is single-zone with no failover."
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be one of: ZONAL, REGIONAL."
  }
}

variable "backup_enabled" {
  description = "Enable automatic backups"
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = "Backup start time (HH:MM)"
  type        = string
  default     = "03:00"
}

variable "public_ip" {
  description = "Enable public IP"
  type        = bool
  default     = false
}

variable "authorized_network" {
  description = "CIDR block permitted to connect over the public IP. Only relevant when `public_ip = true`; ignored for private-only instances."
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_network_id" {
  description = "VPC network ID for private connectivity"
  type        = string
  default     = null
}

variable "vpc_peering_id" {
  description = "ID of the VPC peering connection for Private Service Access (PSA). Not used to configure the instance; exists only to declare an explicit Terraform dependency so the PSA peering is fully established before the instance is created."
  type        = string
  default     = null
}

variable "max_connections" {
  description = "Maximum number of connections"
  type        = string
  default     = "100"
}

variable "deletion_protection" {
  description = "Deletion protection"
  type        = bool
  default     = true
}
