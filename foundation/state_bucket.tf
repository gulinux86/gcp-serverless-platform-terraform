# The Terraform state bucket is intentionally NOT managed by Terraform.
# It must exist before `terraform init` and must outlive `terraform destroy`.
#
# Create it once per environment with:
#   gcloud storage buckets create gs://<bucket-name> \
#     --location=US-CENTRAL1 --uniform-bucket-level-access \
#     --project=<project-id>
#   gcloud storage buckets update gs://<bucket-name> --versioning
#
# Never import it into state — if Terraform manages it, `terraform destroy`
# will delete the bucket while the state lock is still held, causing a 404 error.
