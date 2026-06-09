# Bootstrap — HML. project_id is NOT committed; pass it at apply time:
#   terraform -chdir=bootstrap apply -var-file=environments/hml/terraform.tfvars \
#     -var="project_id=<your-hml-project-id>"
# (state bucket is serverless-<environment>, e.g. serverless-hml)
environment = "hml"
github_repo = "gulinux86/gcp-serverless-platform-terraform"
