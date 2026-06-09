# Bootstrap — PROD. project_id is NOT committed; pass it at apply time:
#   terraform -chdir=bootstrap apply -var-file=environments/prod/terraform.tfvars \
#     -var="project_id=<your-prod-project-id>"
environment = "prod"
github_repo = "gulinux86/gcp-serverless-platform-terraform"
