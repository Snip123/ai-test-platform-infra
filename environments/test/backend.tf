terraform {
  backend "gcs" {
    bucket = "fsi-eam-platform-terraform-state"
    prefix = "environments/test"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.7"
}

provider "google" {
  project = var.project_id
  region  = var.region
}
