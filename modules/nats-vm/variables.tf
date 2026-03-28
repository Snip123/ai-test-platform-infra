variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "zone" {
  type        = string
  description = "GCP zone for the NATS VM (e.g. us-central1-a)"
}

variable "environment" {
  type        = string
  description = "dev | test | production"
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type — e2-micro qualifies for always-free tier (ADR-0010)"
  default     = "e2-micro"
}

variable "disk_size_gb" {
  type        = number
  description = "Persistent disk size in GB for NATS JetStream storage"
  default     = 20
}

variable "nats_version" {
  type        = string
  description = "NATS server Docker image tag"
  default     = "2.10-alpine"
}
