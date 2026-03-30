terraform {
  backend "gcs" {
    # Bucket must be created once manually:
    #   gsutil mb -p $GCP_PROJECT_ID gs://$GCP_PROJECT_ID-terraform-state
    #   gsutil versioning set on gs://$GCP_PROJECT_ID-terraform-state
    bucket = "fsi-eam-platform-terraform-state"
    prefix = "environments/dev"
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
