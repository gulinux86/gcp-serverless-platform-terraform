# Terraform state bucket — imported via:
#   terraform import module.foundation.google_storage_bucket.state_bucket \
#     {project_id}/{bucket_name}
# Do NOT run terraform apply before importing or Terraform will attempt to recreate the bucket.
# The state bucket is intentionally NOT managed by Terraform.
# It must exist before `terraform init` and must outlive `terraform destroy`.
#
# Create it once with:
#   gcloud storage buckets create gs://<bucket-name> \
#     --location=US-CENTRAL1 --uniform-bucket-level-access \
#     --project=<project-id>
#   gcloud storage buckets update gs://<bucket-name> --versioning
#
# Never import it into state — if Terraform manages it, `terraform destroy`
# will delete the bucket while the state lock is still held, causing a 404 error.
