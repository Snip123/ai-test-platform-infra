terraform {
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
}

# Shared Cloud SQL instance — one DB per Tenant (ADR-0007).
resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.instance_name
  database_version    = var.database_version
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier = var.tier

    availability_type = var.environment == "production" ? "REGIONAL" : "ZONAL"

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = var.backup_start_time
      backup_retention_settings {
        retained_backups = var.environment == "production" ? 30 : 7
      }
    }

    ip_configuration {
      # Private IP only — Cloud Run connects via Cloud SQL Auth Proxy or VPC connector.
      # Public IP disabled for production. Enabled in dev/test for psql access from workstations.
      ipv4_enabled    = var.environment != "production"
      private_network = null # set to VPC network ID when VPC peering is configured
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = var.environment == "production" ? "500" : "0"
    }

    insights_config {
      query_insights_enabled = true
    }
  }
}

# Platform databases (keycloak, openfga, fsi_platform).
# Tenant DBs are provisioned by the tenant module, not here.
resource "google_sql_database" "platform_dbs" {
  for_each = toset(var.databases)
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = each.value
}

# Platform admin user — password stored in Secret Manager (ADR-0017).
resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_user" "fsi_admin" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = "fsi"
  password = random_password.db_password.result
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "${var.environment}-cloud-sql-fsi-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
