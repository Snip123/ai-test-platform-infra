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
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.6"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  required_version = ">= 1.7"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "neon" {
  api_key = var.neon_api_key
}
