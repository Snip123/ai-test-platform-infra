# ── DEV ENVIRONMENT ───────────────────────────────────────────────────────────
#
# Lowest-cost environment for infrastructure development and manual testing.
# All Cloud Run services scale to zero (min_instance_count = 0).
# Cloud SQL uses db-f1-micro. NATS VM uses e2-micro (always-free tier).
#
# Deploy:  cd environments/dev && terraform apply
# Destroy: cd environments/dev && terraform destroy
# ─────────────────────────────────────────────────────────────────────────────

locals {
  env         = "dev"
  name_prefix = "${local.env}-"
  image_base  = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
# Single registry shared across all environments (images are tagged per env).
resource "google_artifact_registry_repository" "fsi_platform" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  description   = "FSI EAM/CMMS platform container images"
}

# ── Service Accounts ──────────────────────────────────────────────────────────
resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "${local.name_prefix}cloud-run"
  display_name = "Dev — Cloud Run services"
}

# Allow Cloud Run SA to access Secret Manager (ADR-0017)
resource "google_project_iam_member" "cloud_run_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Allow Cloud Run SA to connect to Cloud SQL via Auth Proxy
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

  databases           = ["keycloak", "openfga", "tenant_dev"]
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
  source         = "../../modules/cloud-run-service"
  project_id     = var.project_id
  region         = var.region
  service_name   = "${local.name_prefix}ai-test-gateway-service"
  image          = "${local.image_base}/ai-test-gateway-service:${var.image_tag}"
  environment    = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count = 0
  max_instance_count = 3
  allow_public_ingress = true

  env_vars = {
    PORT                 = "8080"
    AUTH_DISABLED        = "true"
    UPSTREAM_ASSETS_URL  = module.assets.url
  }
}

# ── Assets service ────────────────────────────────────────────────────────────
module "assets" {
  source         = "../../modules/cloud-run-service"
  project_id     = var.project_id
  region         = var.region
  service_name   = "${local.name_prefix}ai-test-assets-service"
  image          = "${local.image_base}/ai-test-assets-service:${var.image_tag}"
  environment    = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count = 0
  max_instance_count = 3
  allow_public_ingress = false

  env_vars = {
    PORT             = "8080"
    NATS_URL         = module.nats.nats_url
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
  source         = "../../modules/cloud-run-service"
  project_id     = var.project_id
  region         = var.region
  service_name   = "${local.name_prefix}keycloak"
  image          = "quay.io/keycloak/keycloak:24.0"
  environment    = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count = 0
  max_instance_count = 1
  memory             = "1Gi"
  allow_public_ingress = true

  env_vars = {
    KC_DB           = "postgres"
    KEYCLOAK_ADMIN  = "admin"
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
  source         = "../../modules/cloud-run-service"
  project_id     = var.project_id
  region         = var.region
  service_name   = "${local.name_prefix}openfga"
  image          = "openfga/openfga:latest"
  environment    = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count = 0
  max_instance_count = 2
  allow_public_ingress = false

  env_vars = {
    OPENFGA_DATASTORE_ENGINE     = "postgres"
    OPENFGA_PLAYGROUND_ENABLED   = "true"
  }

  secret_env_vars = [
    {
      env_var     = "OPENFGA_DATASTORE_URI"
      secret_name = "${local.env}-openfga-db-url"
      version     = "latest"
    }
  ]
}
