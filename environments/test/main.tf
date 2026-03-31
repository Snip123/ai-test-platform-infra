# ── TEST ENVIRONMENT ──────────────────────────────────────────────────────────
#
# Staging / integration test environment. Auto-deployed from main (ADR-0013).
#
# Idle cost: $0/month
#   - Cloud Run services: scale to zero (min_instance_count = 0)
#   - PostgreSQL: Neon serverless — suspends after 5 min idle (ADR-0019)
#   - NATS VM: GCP always-free e2-micro (1 free per project)
#
# Deploy:  terraform apply (handled by CI on main merge)
# Destroy: terraform destroy
# ─────────────────────────────────────────────────────────────────────────────

locals {
  env         = "test"
  name_prefix = "${local.env}-"
  image_base  = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}"
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
# Defined here (test is the first environment to run in CI).
# Shared across test and production — images are tagged per environment.
resource "google_artifact_registry_repository" "fsi_platform" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  description   = "FSI EAM/CMMS platform container images"
}

# ── Service Account ───────────────────────────────────────────────────────────
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

# ── Neon serverless Postgres (ADR-0019) ───────────────────────────────────────
# Replaces Cloud SQL for non-production. Scales to zero — $0 idle cost.
module "neon" {
  source       = "../../modules/neon-environment"
  environment  = local.env
  neon_api_key = var.neon_api_key
  neon_org_id  = var.neon_org_id
  project_id   = var.project_id
  databases    = ["keycloak", "openfga", "tenant_test"]
}

# ── Keycloak admin password ───────────────────────────────────────────────────
# Generated once; stored in Secret Manager; not rotated by Terraform.
resource "random_password" "keycloak_admin" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "keycloak_admin_password" {
  project   = var.project_id
  secret_id = "${local.env}-keycloak-admin-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "keycloak_admin_password" {
  secret      = google_secret_manager_secret.keycloak_admin_password.id
  secret_data = random_password.keycloak_admin.result
}

# ── NATS JetStream VM ─────────────────────────────────────────────────────────
# GCP always-free e2-micro (1 per project) — $0/month.
# Shared by dev (local) and test (cloud). Production gets its own VM.
module "nats" {
  source       = "../../modules/nats-vm"
  project_id   = var.project_id
  zone         = var.zone
  environment  = local.env
  machine_type = "e2-micro"
  disk_size_gb = 10
}

# ── Gateway service ───────────────────────────────────────────────────────────
# Placeholder image — CI/CD replaces via gcloud run deploy; lifecycle.ignore_changes prevents rollback.
module "gateway" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}ai-test-gateway-service"
  image                 = "us-docker.pkg.dev/cloudrun/container/hello:latest"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 5
  allow_public_ingress = true

  env_vars = {
    AUTH_DISABLED       = "false"
    UPSTREAM_ASSETS_URL = module.assets.url
    KEYCLOAK_URL        = module.keycloak.url
    OPENFGA_URL         = module.openfga.url
  }

  depends_on = [google_project_iam_member.cloud_run_secrets]
}

# ── Assets service ────────────────────────────────────────────────────────────
# Placeholder image — CI/CD replaces via gcloud run deploy; lifecycle.ignore_changes prevents rollback.
module "assets" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}ai-test-assets-service"
  image                 = "us-docker.pkg.dev/cloudrun/container/hello:latest"
  environment           = local.env
  service_account_email = google_service_account.cloud_run.email

  min_instance_count   = 0
  max_instance_count   = 5
  allow_public_ingress = false

  env_vars = {
    NATS_URL          = module.nats.nats_url
    OTEL_SERVICE_NAME = "ai-test-assets-service"
  }

  secret_env_vars = [
    {
      env_var     = "DATABASE_URL"
      secret_name = module.neon.db_secret_ids["tenant_test"]
      version     = "latest"
    }
  ]

  depends_on = [google_project_iam_member.cloud_run_secrets]
}

# ── Keycloak ─────────────────────────────────────────────────────────────────
# docker.io required — Cloud Run v2 only accepts gcr.io, docker.pkg.dev, or docker.io.
module "keycloak" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}keycloak"
  image                 = "docker.io/keycloak/keycloak:24.0"
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
      secret_name = module.neon.db_secret_ids["keycloak"]
      version     = "latest"
    }
  ]

  depends_on = [
    google_project_iam_member.cloud_run_secrets,
    google_secret_manager_secret_version.keycloak_admin_password,
  ]
}

# ── OpenFGA ──────────────────────────────────────────────────────────────────
# docker.io required — Cloud Run v2 only accepts gcr.io, docker.pkg.dev, or docker.io.
module "openfga" {
  source                = "../../modules/cloud-run-service"
  project_id            = var.project_id
  region                = var.region
  service_name          = "${local.name_prefix}openfga"
  image                 = "docker.io/openfga/openfga:latest"
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
      secret_name = module.neon.db_secret_ids["openfga"]
      version     = "latest"
    }
  ]

  depends_on = [google_project_iam_member.cloud_run_secrets]
}
