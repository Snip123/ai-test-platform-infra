terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = var.allow_public_ingress ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    max_instance_request_concurrency = var.concurrency

    timeout = "${var.timeout_seconds}s"

    dynamic "vpc_access" {
      for_each = var.vpc_connector_name != null ? [1] : []
      content {
        connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        # CPU is only allocated during request processing — not on idle instances.
        # This is the correct setting for scale-to-zero (ADR-0010).
        cpu_idle          = false
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = merge(
          var.env_vars,
          { ENVIRONMENT = var.environment }
        )
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.value.env_var
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      liveness_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 10
        period_seconds        = 30
        failure_threshold     = 3
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }
    }

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }

  lifecycle {
    # image tag is managed by CI/CD deploys, not Terraform.
    # Prevent Terraform from rolling back image on every plan.
    ignore_changes = [template[0].containers[0].image]
  }
}

# Allow unauthenticated access — only set for the public-facing gateway (ADR-0011).
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count    = var.allow_public_ingress ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
