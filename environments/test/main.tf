# ── TEST ENVIRONMENT ──────────────────────────────────────────────────────────
#
# Staging / integration test environment.
# Auto-deployed from main branch via GitHub Actions (ADR-0013).
# All Cloud Run services scale to zero (min_instance_count = 0).
# Cloud SQL uses db-f1-micro.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  env         = "test"
  name_prefix = "${local.env}-"
  image_base  = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}"
}

# ── Service Accounts ──────────────────────────────────────────────────────────
resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "${local.name_prefix}cloud-run"
  display_name = "Test — Cloud Run services"
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
  instance_name = "${local.name_prefix}fsi-postgres"
  tier          = "db-f1-micro"

  databases           = ["keycloak", "openfga", "tenant_test"]
  backup_enabled      = false
  deletion_protection = false
}

# ── NATS JetStream VM ─────────────────────────────────────────────────────────
module "nats" {
  source       = "../../modules/nats-vm"
  project_id   = var.project_id
  zone         = var.zone
  environment  = local.env
  machine_type = "e2-micro"
  disk_size_gb = 10
}

# ── Gateway service ───────────────────────────────────────────────────────────
module "gateway" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}ai-test-gateway-service"
  image                 = "${local.image_base}/ai-test-gateway-service:${var.image_tag}"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 5
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
  service_name          = "${local.name_prefix}ai-test-assets-service"
  image                 = "${local.image_base}/ai-test-assets-service:${var.image_tag}"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 5
  allow_public_ingress = false

  env_vars = {
    PORT              = "8080"
    NATS_URL          = module.nats.nats_url
    OTEL_SERVICE_NAME = "ai-test-assets-service"
  }

  secret_env_vars = [
    {
      env_var     = "DATABASE_URL"
      secret_name = "${local.env}-cloud-sql-fsi-password"
      version     = "latest"
    }
  ]
}

# ── Keycloak ──────────────────────────────────────────────────────────────────
module "keycloak" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}keycloak"
  image                 = "quay.io/keycloak/keycloak:24.0"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 2
  memory               = "1Gi"
  allow_public_ingress = true

  env_vars = {
    KC_DB          = "postgres"
    KEYCLOAK_ADMIN = "admin"
  }

  secret_env_vars = [
    {
      env_var     = "KEYCLOAK_ADMIN_PASSWORD"
      secret_name = "${local.env}-keycloak-admin-password"
      version     = "latest"
    },
    {
      env_var     = "KC_DB_URL"
      secret_name = "${local.env}-keycloak-db-url"
      version     = "latest"
    }
  ]
}

# ── OpenFGA ───────────────────────────────────────────────────────────────────
module "openfga" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}openfga"
  image                 = "openfga/openfga:latest"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 3
  allow_public_ingress = false

  env_vars = {
    OPENFGA_DATASTORE_ENGINE   = "postgres"
    OPENFGA_PLAYGROUND_ENABLED = "false"
  }

  secret_env_vars = [
    {
      env_var     = "OPENFGA_DATASTORE_URI"
      secret_name = "${local.env}-openfga-db-url"
      version     = "latest"
    }
  ]
}
