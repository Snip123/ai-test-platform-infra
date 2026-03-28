output "internal_ip" {
  description = "Internal IP address of the NATS VM — used by Cloud Run services as NATS_URL"
  value       = google_compute_instance.nats.network_interface[0].network_ip
}

output "nats_url" {
  description = "NATS client URL for use in service env vars"
  value       = "nats://${google_compute_instance.nats.network_interface[0].network_ip}:4222"
}

output "vm_name" {
  value = google_compute_instance.nats.name
}
