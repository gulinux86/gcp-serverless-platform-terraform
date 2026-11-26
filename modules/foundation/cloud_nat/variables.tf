variable "name" {
  description = "Name prefix. Produces '<name>-router' and '<name>-nat'."
  type        = string
}

variable "region" {
  description = "Region of the router and NAT gateway. Must match the node subnet's region."
  type        = string
}

variable "network_id" {
  description = "VPC network ID the router is attached to."
  type        = string
}

variable "subnet_id" {
  description = "Node subnet whose primary and secondary ranges get a NAT path."
  type        = string
}

variable "log_filter" {
  description = "NAT logging filter: ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.log_filter)
    error_message = "log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}
