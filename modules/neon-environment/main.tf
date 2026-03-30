terraform {
  required_providers {
    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.6"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Neon serverless Postgres — scales compute to zero after 5 min idle (ADR-0019).
# Free tier: 1 project, 0.5 GB storage, auto-suspend. No idle cost.
resource "neon_project" "this" {
  name       = "fsi-platform-${var.environment}"
  region_id  = "aws-us-east-1"
  pg_version = 16

  default_endpoint_settings {
    # Scale to zero after 5 minutes idle (300s).
    # First request after idle incurs ~500ms cold start — acceptable for non-production.
    suspend_timeout_seconds  = 300
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 0.25
  }
}

# Application role — matches the 'fsi' user used in local docker-compose (ADR-0007).
resource "neon_role" "fsi" {
  project_id = neon_project.this.id
  branch_id  = neon_project.this.default_branch_id
  name       = "fsi"
}

# Platform databases — one per platform service that needs its own schema.
# Tenant databases are provisioned by scripts/provision-tenant.sh, not here.
resource "neon_database" "platform" {
  for_each = toset(var.databases)

  project_id = neon_project.this.id
  branch_id  = neon_project.this.default_branch_id
  name       = each.value
  owner_name = neon_role.fsi.name
}

locals {
  # Extract hostname from the project's default connection URI.
  # Neon URI format: postgres://user:pass@hostname/neondb?sslmode=require
  neon_host = split("/", split("@", neon_project.this.connection_uri)[1])[0]
}

# Store per-database connection strings in GCP Secret Manager (ADR-0017).
# Cloud Run services read DATABASE_URL from Secret Manager at startup.
resource "google_secret_manager_secret" "db_url" {
  for_each  = toset(var.databases)
  project   = var.project_id
  secret_id = "${var.environment}-db-url-${replace(each.value, "_", "-")}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_url" {
  for_each = toset(var.databases)
  secret   = google_secret_manager_secret.db_url[each.value].id

  secret_data = "postgres://${neon_role.fsi.name}:${neon_role.fsi.password}@${local.neon_host}/${each.value}?sslmode=require"
}
