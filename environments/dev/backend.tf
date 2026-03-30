# Dev runs locally — no cloud resources to manage.
# This backend block is here so `terraform init` works if someone adds resources later.
terraform {
  backend "gcs" {
    bucket = "fsi-eam-platform-terraform-state"
    prefix = "environments/dev"
  }

  required_version = ">= 1.7"
}
