# Workload layer — PROD. project_id, db_password, api_secret_key via TF_VAR_* (secrets).
name         = "app-prod"
region       = "us-central1"
environment  = "prod"
state_bucket = "serverless-prod"
