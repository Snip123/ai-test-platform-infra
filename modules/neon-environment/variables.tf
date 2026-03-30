variable "environment" {
  type        = string
  description = "dev | test"
  validation {
    condition     = contains(["dev", "test"], var.environment)
    error_message = "Neon is for non-production environments only. Use modules/cloud-sql for production."
  }
}

variable "neon_api_key" {
  type        = string
  description = "Neon API key — obtain from https://console.neon.tech/app/settings/api-keys"
  sensitive   = true
}

variable "project_id" {
  type        = string
  description = "GCP project ID — used to store connection strings in Secret Manager"
}

variable "databases" {
  type        = list(string)
  description = "List of database names to create in the Neon project"
  default     = ["keycloak", "openfga", "tenant_dev"]
}
