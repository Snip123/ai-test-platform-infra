variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for Cloud Run"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name (include env prefix e.g. test-ai-test-assets-service)"
}

variable "image" {
  type        = string
  description = "Full container image URL including tag"
}

variable "environment" {
  type        = string
  description = "deployment environment: dev | test | production"
  validation {
    condition     = contains(["dev", "test", "production"], var.environment)
    error_message = "environment must be dev, test, or production"
  }
}

variable "min_instance_count" {
  type        = number
  description = "Minimum Cloud Run instances — 0 = scales to zero"
  default     = 0
}

variable "max_instance_count" {
  type        = number
  description = "Maximum Cloud Run instances"
  default     = 5
}

variable "concurrency" {
  type        = number
  description = "Max concurrent requests per instance"
  default     = 80
}

variable "cpu" {
  type        = string
  description = "CPU allocation (e.g. '1', '2')"
  default     = "1"
}

variable "memory" {
  type        = string
  description = "Memory allocation (e.g. '512Mi', '1Gi')"
  default     = "512Mi"
}

variable "timeout_seconds" {
  type        = number
  description = "Request timeout in seconds"
  default     = 30
}

variable "env_vars" {
  type        = map(string)
  description = "Plain environment variables injected at runtime"
  default     = {}
}

variable "secret_env_vars" {
  type = list(object({
    env_var     = string
    secret_name = string
    version     = string
  }))
  description = "Secret Manager secrets mounted as environment variables"
  default     = []
}

variable "service_account_email" {
  type        = string
  description = "Service account the Cloud Run service runs as"
}

variable "allow_public_ingress" {
  type        = bool
  description = "Allow unauthenticated requests from the internet (true for the gateway, false for internal services)"
  default     = false
}

variable "vpc_connector_name" {
  type        = string
  description = "VPC serverless connector name for private Cloud SQL and NATS access (optional)"
  default     = null
}
