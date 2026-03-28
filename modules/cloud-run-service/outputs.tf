output "url" {
  description = "The public URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "name" {
  description = "The Cloud Run service name"
  value       = google_cloud_run_v2_service.this.name
}

output "service_account_email" {
  description = "The service account running this Cloud Run service"
  value       = var.service_account_email
}
