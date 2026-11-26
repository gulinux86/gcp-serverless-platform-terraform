variable "project_id" {
  description = "GCP project ID for this environment (where the deployer SA and WIF pool live)."
  type        = string
}

variable "environment" {
  description = "Environment name (hml | prod). Used to namespace the WIF pool/provider and the deployer SA."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in 'owner/repo' form. The WIF provider only mints tokens for this repo."
  type        = string
}

variable "project_services" {
  description = "APIs the foundation and workload layers need."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "containersecurity.googleapis.com",
  ]
}

variable "plan_roles" {
  description = "Project-level roles of the read-only plan service account. Viewer reads the resources; Security Reviewer reads the IAM policies that the *_iam_member resources refresh."
  type        = list(string)
  default = [
    "roles/viewer",
    "roles/iam.securityReviewer",
  ]
}

variable "deployer_roles" {
  description = "Project-level roles granted to the deployer service account. Scoped to exactly what the foundation + workload layers provision."
  type        = list(string)
  default = [
    "roles/compute.networkAdmin",            # VPC, subnets, router/NAT, addresses
    "roles/compute.securityAdmin",           # Firewall rules, Cloud Armor policy, SSL certs
    "roles/servicenetworking.networksAdmin", # PSA peering for Cloud SQL
    "roles/container.admin",                 # GKE cluster + node pools, and cluster-admin in-cluster (Argo CD install)
    "roles/cloudsql.admin",                  # Cloud SQL instance + database
    "roles/secretmanager.admin",             # Secrets + per-secret IAM
    "roles/storage.admin",                   # GCS buckets (app, audit logs, state read)
    "roles/artifactregistry.admin",          # Docker repository
    "roles/monitoring.admin",                # Alert policies
    "roles/logging.admin",                   # Log sink
    "roles/iam.serviceAccountAdmin",         # node SA, backend/frontend/ESO SAs + Workload Identity bindings
    "roles/iam.serviceAccountUser",          # actAs the node SA when creating node pools
    "roles/resourcemanager.projectIamAdmin", # per-resource IAM bindings
  ]
}
