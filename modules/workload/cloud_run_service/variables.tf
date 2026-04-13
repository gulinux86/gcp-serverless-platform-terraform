variable "name" {
  description = "Cloud Run service name"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
  default     = "us-central1"
}

variable "image" {
  description = "Container image (e.g., gcr.io/project/image:tag)"
  type        = string
}

variable "memory" {
  description = "Container memory allocation (e.g., 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "cpu" {
  description = "Container CPU"
  type        = string
  default     = "1"
}

variable "env_vars" {
  description = "Container environment variables"
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "Service account email"
  type        = string
  default     = null
}

variable "vpc_subnet_id" {
  description = "VPC Subnet ID for Direct VPC Egress"
  type        = string
  default     = null
}

variable "gcs_bucket_name" {
  description = "GCS bucket name for FUSE mount"
  type        = string
  default     = null
}

variable "mount_path" {
  description = "Path to mount the GCS bucket"
  type        = string
  default     = "/mnt/gcs"
}

variable "make_public" {
  description = "Whether to allow unauthenticated access"
  type        = bool
  default     = true
}

variable "ingress" {
  description = "Cloud Run ingress setting. INGRESS_TRAFFIC_ALL allows direct *.run.app access. INGRESS_TRAFFIC_INTERNAL_ONLY restricts to VPC-originating traffic. INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER allows only traffic through a Google Cloud Load Balancer (recommended for production)."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "ingress must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "min_instance_count" {
  description = "Minimum number of instances to keep warm (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "secret_env_vars" {
  description = "Map of env var name to Secret Manager secret reference. Each entry injects the secret value as an environment variable without exposing it as plain text."
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}
