variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "environment" {
  type        = string
  description = "dev | test | production"
}

variable "instance_name" {
  type        = string
  description = "Cloud SQL instance name (must be unique per project)"
}

variable "database_version" {
  type        = string
  description = "PostgreSQL version"
  default     = "POSTGRES_16"
}

variable "tier" {
  type        = string
  description = "Cloud SQL machine tier (e.g. db-f1-micro, db-g1-small, db-custom-2-4096)"
  default     = "db-f1-micro"
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion — set false in dev/test, true in production"
  default     = false
}

variable "databases" {
  type        = list(string)
  description = "List of database names to create in the shared instance"
  default     = ["keycloak", "openfga", "fsi_platform"]
}

variable "backup_enabled" {
  type        = bool
  description = "Enable automated backups"
  default     = false
}

variable "backup_start_time" {
  type        = string
  description = "Daily backup window start time (HH:MM)"
  default     = "02:00"
}
