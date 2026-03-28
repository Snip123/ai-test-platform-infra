variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone for the NATS VM"
  default     = "us-central1-a"
}

variable "artifact_registry_repo" {
  type        = string
  description = "Artifact Registry repository name"
  default     = "fsi-platform"
}

variable "image_tag" {
  type        = string
  description = "Container image tag — set by CI/CD on tagged releases"
}

variable "sql_tier" {
  type        = string
  description = "Cloud SQL machine tier — upgrade as Tenant count grows"
  default     = "db-g1-small"
}
