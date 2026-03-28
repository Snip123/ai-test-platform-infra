output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Cloud SQL connection name for Auth Proxy (project:region:instance)"
  value       = google_sql_database_instance.this.connection_name
}

output "public_ip" {
  description = "Public IP address (null in production)"
  value       = google_sql_database_instance.this.public_ip_address
}

output "db_password_secret_id" {
  description = "Secret Manager secret ID for the fsi admin DB password"
  value       = google_secret_manager_secret.db_password.secret_id
}
