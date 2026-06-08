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

variable "deployer_roles" {
  description = "Project-level roles granted to the deployer service account. Scoped to exactly what the foundation + workload layers provision."
  type        = list(string)
  default = [
    "roles/compute.networkAdmin",            # VPC, subnets, firewall, addresses
    "roles/vpcaccess.admin",                 # Serverless VPC Access Connector
    "roles/servicenetworking.networksAdmin", # PSA peering for Cloud SQL
    "roles/run.admin",                       # Cloud Run services + jobs
    "roles/cloudsql.admin",                  # Cloud SQL instance + database
    "roles/secretmanager.admin",             # Secrets + rotation
    "roles/storage.admin",                   # GCS buckets (app, audit logs, state read)
    "roles/artifactregistry.admin",          # Docker repository
    "roles/pubsub.admin",                    # Secret-rotation topic/subscription
    "roles/monitoring.admin",                # Alert policies
    "roles/logging.admin",                   # Log sink
    "roles/iam.serviceAccountAdmin",         # backend-sa / frontend-sa
    "roles/iam.serviceAccountUser",          # actAs the workload SAs
    "roles/resourcemanager.projectIamAdmin", # per-resource IAM bindings
  ]
}
