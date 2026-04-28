variable "project_id" {
  type = string
}

variable "name" {
  type    = string
  default = "app-hml"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "api_secret_key" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type     = string
  default  = null
  nullable = true
}

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "db_availability_type" {
  type    = string
  default = "ZONAL"
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

module "platform" {
  source = "../../"

  project_id             = var.project_id
  name                   = var.name
  region                 = var.region
  db_password            = var.db_password
  api_secret_key         = var.api_secret_key
  domain_name            = var.domain_name
  db_tier                = var.db_tier
  db_availability_type   = var.db_availability_type
  db_deletion_protection = var.db_deletion_protection
}
