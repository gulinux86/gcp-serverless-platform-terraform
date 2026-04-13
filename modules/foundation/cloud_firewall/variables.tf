variable "name" {
  description = "Base name for firewall rules"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "allowed_ports" {
  description = "TCP ports to allow inbound. Defaults to HTTP (80), HTTPS (443), and common application port (8080)."
  type        = list(string)
  default     = ["80", "443", "8080"]
}

variable "source_ranges" {
  description = "Source CIDR ranges for the ingress allow rule. Defaults to RFC-1918 private address space (10.0.0.0/8)."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "target_tags" {
  description = "Network tags identifying instances this rule applies to. An empty list applies the rule to all instances in the network."
  type        = list(string)
  default     = []
}

variable "create_deny_rule" {
  description = "When true, adds a low-priority deny-all rule for traffic not matched by any allow rule, enforcing explicit deny-by-default posture."
  type        = bool
  default     = false
}
