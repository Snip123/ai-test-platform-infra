# ── PRODUCTION ENVIRONMENT ────────────────────────────────────────────────────
#
# Production environment deployed on version tags via GitHub Actions (ADR-0013).
# Manual approval gate is enforced by the GitHub Environment "production" protection rules.
# All Cloud Run services scale to zero (min_instance_count = 0) per ADR-0010.
# Cloud SQL uses REGIONAL availability for HA.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  env        = "production"
  image_base = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
# Owned by production — the most persistent environment.
# Shared with test (images tagged per environment).
# Created in environments/test too for CI bootstrapping; Terraform import resolves any conflict.
resource "google_artifact_registry_repository" "fsi_platform" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  description   = "FSI EAM/CMMS platform container images"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Service Accounts ──────────────────────────────────────────────────────────
resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "prod-cloud-run"
  display_name = "Production — Cloud Run services"
}

resource "google_project_iam_member" "cloud_run_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
module "cloud_sql" {
  source        = "../../modules/cloud-sql"
  project_id    = var.project_id
  region        = var.region
  environment   = local.env
  instance_name = "prod-fsi-postgres"
  tier          = var.sql_tier

  databases           = ["keycloak", "openfga"]
  backup_enabled      = true
  backup_start_time   = "02:00"
  deletion_protection = true
}

# ── NATS JetStream VM ─────────────────────────────────────────────────────────
# NATS cannot scale to zero — e2-micro is always-free (ADR-0010).
# Migrate to NATS cluster on GKE Autopilot at ~10 Tenants.
module "nats" {
  source       = "../../modules/nats-vm"
  project_id   = var.project_id
  zone         = var.zone
  environment  = local.env
  machine_type = "e2-micro"
  disk_size_gb = 20
}

# ── Gateway service ───────────────────────────────────────────────────────────
module "gateway" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "ai-test-gateway-service"
  image                 = "${local.image_base}/ai-test-gateway-service:${var.image_tag}"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  # Scale to zero — cold start latency is acceptable for this platform (ADR-0010).
  # If cold start SLA becomes a concern, set min_instance_count = 1.
  min_instance_count   = 0
  max_instance_count   = 10
  allow_public_ingress = true

  env_vars = {
    PORT                = "8080"
    AUTH_DISABLED       = "false"
    UPSTREAM_ASSETS_URL = module.assets.url
    KEYCLOAK_URL        = module.keycloak.url
    OPENFGA_URL         = module.openfga.url
  }
}

# ── Assets service ────────────────────────────────────────────────────────────
module "assets" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "ai-test-assets-service"
  image                 = "${local.image_base}/ai-test-assets-service:${var.image_tag}"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 10
  allow_public_ingress = false

  env_vars = {
    PORT              = "8080"
    NATS_URL          = module.nats.nats_url
    OTEL_SERVICE_NAME = "ai-test-assets-service"
  }

  secret_env_vars = [
    {
      env_var     = "DATABASE_URL"
      secret_name = "production-cloud-sql-fsi-password"
      version     = "latest"
    }
  ]
}

# ── Keycloak ──────────────────────────────────────────────────────────────────
module "keycloak" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "keycloak"
  image                 = "quay.io/keycloak/keycloak:24.0"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 3
  memory               = "1Gi"
  allow_public_ingress = true

  env_vars = {
    KC_DB          = "postgres"
    KEYCLOAK_ADMIN = "admin"
  }

  secret_env_vars = [
    {
      env_var     = "KEYCLOAK_ADMIN_PASSWORD"
      secret_name = "production-keycloak-admin-password"
      version     = "latest"
    },
    {
      env_var     = "KC_DB_URL"
      secret_name = "production-keycloak-db-url"
      version     = "latest"
    }
  ]
}

# ── OpenFGA ───────────────────────────────────────────────────────────────────
module "openfga" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "openfga"
  image                 = "openfga/openfga:latest"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 5
  allow_public_ingress = false

  env_vars = {
    OPENFGA_DATASTORE_ENGINE   = "postgres"
    OPENFGA_PLAYGROUND_ENABLED = "false"
  }

  secret_env_vars = [
    {
      env_var     = "OPENFGA_DATASTORE_URI"
      secret_name = "production-openfga-db-url"
      version     = "latest"
    }
  ]
}
