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
  description = "Container image tag — CI/CD writes the SHA here on each deploy"
  default     = "latest"
}

variable "neon_api_key" {
  type        = string
  description = "Neon API key — obtain from https://console.neon.tech/app/settings/api-keys. Set as TF_VAR_neon_api_key or in terraform.tfvars (gitignored)."
  sensitive   = true
}

variable "neon_org_id" {
  type        = string
  description = "Neon organization ID — find at https://console.neon.tech/app/settings. Set as NEON_ORG_ID repo variable in GitHub Actions."
}
