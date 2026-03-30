terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# NATS JetStream requires persistent storage — cannot run on Cloud Run (ADR-0010).
# e2-micro is always-free on GCP (one per project). One VM per environment.

locals {
  vm_name = "${var.environment}-nats"
}

resource "google_compute_disk" "nats_data" {
  project = var.project_id
  name    = "${local.vm_name}-data"
  zone    = var.zone
  size    = var.disk_size_gb
  type    = "pd-standard"

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

resource "google_compute_instance" "nats" {
  project      = var.project_id
  name         = local.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable" # Container-Optimized OS — runs Docker natively
      size  = 10
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.nats_data.id
    device_name = "nats-data"
  }

  network_interface {
    network = "default"
    # No external IP in production — access via internal VPC only.
    # Dev/test get ephemeral external IPs for easier access.
    dynamic "access_config" {
      for_each = var.environment != "production" ? [1] : []
      content {}
    }
  }

  # Container declaration — COS starts Docker containers at boot.
  metadata = {
    gce-container-declaration = yamlencode({
      spec = {
        containers = [{
          name  = "nats"
          image = "nats:${var.nats_version}"
          args  = ["-js", "-sd", "/data", "-m", "8222"]
          volumeMounts = [{
            name      = "nats-data"
            mountPath = "/data"
          }]
          ports = [
            { containerPort = 4222 }, # client
            { containerPort = 8222 }  # monitoring
          ]
        }]
        volumes = [{
          name = "nats-data"
          gcePersistentDisk = {
            pdName = "nats-data"
            fsType = "ext4"
          }
        }]
        restartPolicy = "Always"
      }
    })
  }

  tags = ["nats-server", var.environment]

  labels = {
    environment = var.environment
    managed-by  = "terraform"
    role        = "nats"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  # Prevent replacement on metadata changes (e.g. NATS version update).
  # Use `terraform taint` to force recreation when needed.
  lifecycle {
    ignore_changes = [metadata]
  }
}

# Firewall: allow NATS client connections from Cloud Run VPC connector.
resource "google_compute_firewall" "nats_internal" {
  project = var.project_id
  name    = "${local.vm_name}-allow-internal"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["4222"]
  }

  source_tags = [var.environment]
  target_tags = ["nats-server"]

  description = "Allow NATS client connections from ${var.environment} Cloud Run services"
}
