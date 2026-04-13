variable "name" {
  description = "Bucket name (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Bucket location"
  type        = string
  default     = "US"
}

variable "force_destroy" {
  description = "Allow bucket deletion even if not empty"
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable object versioning"
  type        = bool
  default     = false
}

variable "lifecycle_age" {
  description = "Age in days to apply lifecycle rule"
  type        = number
  default     = 30
}

variable "lifecycle_action" {
  description = "Lifecycle action (Delete, SetStorageClass)"
  type        = string
  default     = "Delete"
}

variable "public_access" {
  description = "Allow public access to the bucket"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Bucket labels"
  type        = map(string)
  default     = {}
}
