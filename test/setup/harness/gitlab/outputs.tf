output "gitlab_webhook_secret_id" {
  value = google_secret_manager_secret.gitlab_webhook.id
}

output "gitlab_pat_secret_name" {
  value = "gitlab-pat-from-vm"
}

output "gitlab_project_id" {
  value = var.project_id
}

output "gitlab_url" {
  value = "https://${google_compute_instance.default.network_interface[0].access_config[0].nat_ip}.sslip.io"
}

output "gitlab_secret_project" {
  value = var.project_id
}

output "gitlab_instance_zone" {
  value = google_compute_instance.default.zone
}

output "gitlab_instance_name" {
  value = google_compute_instance.default.name
}

output "gitlab_service_directory" {
  value = google_service_directory_service.gitlab.id
}
