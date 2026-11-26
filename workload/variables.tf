variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "name" {
  type        = string
  description = "Human-readable name prefix for all GCP resources"
}

variable "region" {
  type        = string
  description = "Default region"
  default     = "us-central1"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "api_secret_key" {
  type        = string
  description = "API secret key"
  sensitive   = true
}

# Networking and cluster attributes are not inputs. They are read from the
# foundation layer's remote state (see remote_state.tf).

variable "state_bucket" {
  type        = string
  description = "GCS bucket holding the Terraform state for all layers. Used to read the foundation layer's remote state."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. hml, prod). Selects the foundation remote-state prefix (<environment>/foundation)."
}

variable "domain_name" {
  type        = string
  description = "Custom domain for the Google-managed certificate the Gateway terminates TLS with (optional)"
  default     = null
  nullable    = true
}

# --- Workload Identity ----------------------------------------------------------
# "<namespace>/<ksa>" pairs. They must match the ServiceAccounts the GitOps
# repository's charts create, or the pods silently get no Google credentials.

variable "backend_ksas" {
  type        = list(string)
  description = "Kubernetes SAs that act as backend-sa."
}

variable "frontend_ksas" {
  type        = list(string)
  description = "Kubernetes SAs that act as frontend-sa."
}

variable "external_secrets_ksas" {
  type        = list(string)
  description = "Kubernetes SA of the External Secrets Operator controller."
}

# --- Argo CD ----------------------------------------------------------------------

variable "argocd_chart_version" {
  type        = string
  description = "argo-cd Helm chart version. Chart 10.4.0 ships Argo CD v3.5.1."
}

variable "platform_repo_url" {
  type        = string
  description = "Git repository holding platform components. The platform AppProject accepts sources only from the platform_source_repos list."
}

variable "platform_repo_revision" {
  type        = string
  description = "Branch or tag the root Application tracks. A branch follows every commit; a tag makes promotion explicit."
}

variable "platform_repo_path" {
  type        = string
  description = "Directory in the platform repository that holds the child Applications."
}

variable "apps_repo_url" {
  type        = string
  description = "Git repository that holds applications. May be the same as the platform repository."
}

variable "apps_namespaces" {
  type        = list(string)
  description = "Namespace patterns the apps project may deploy into. Prefix globs avoid a Terraform change per application while keeping system namespaces unreachable."
}

variable "platform_source_repos" {
  type        = list(string)
  description = "Repositories the platform project may source from, chart repositories included. Enumerated rather than \"*\" so a component cannot be installed from an arbitrary registry."
}

variable "apps_source_repos" {
  type        = list(string)
  description = "Repositories the apps project may source from, chart repositories included."
}
