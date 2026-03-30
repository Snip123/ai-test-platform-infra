output "neon_project_id" {
  description = "Neon project ID"
  value       = neon_project.this.id
}

output "neon_host" {
  description = "Neon endpoint hostname — for constructing additional connection strings"
  value       = local.neon_host
}

output "db_secret_ids" {
  description = "Map of database name → GCP Secret Manager secret ID for the connection string"
  value       = { for db, s in google_secret_manager_secret.db_url : db => s.secret_id }
}
