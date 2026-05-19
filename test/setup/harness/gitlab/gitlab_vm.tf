locals {
  gitlab_network_url = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/global/networks/${var.network_name}"
}

resource "google_service_account" "gitlab_vm" {
  account_id   = "gitlab-vm-sa"
  project      = var.project_id
  display_name = "Custom SA for VM Instance"
}

resource "google_project_iam_member" "secret_manager_admin_vm_instance" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = google_service_account.gitlab_vm.member
}

resource "google_compute_subnetwork" "gitlab_subnet" {
  project       = var.project_id
  name          = "gitlab-vm-subnet"
  ip_cidr_range = "10.2.2.0/24"
  region        = "us-central1"
  network       = var.network_id
}

resource "google_compute_instance" "default" {
  name         = "gitlab"
  project      = var.project_id
  machine_type = "n2-standard-4"
  zone         = "us-central1-a"

  tags = ["git-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = var.network_name
    access_config {} # Ephemeral public IP
    subnetwork         = google_compute_subnetwork.gitlab_subnet.name
    subnetwork_project = var.project_id
  }

  metadata_startup_script = file("./../../scripts/gitlab_self_hosted.sh")

  service_account {
    email  = google_service_account.gitlab_vm.email
    scopes = ["cloud-platform"]
  }
}

resource "google_secret_manager_secret" "gitlab_webhook" {
  project   = var.project_id
  secret_id = "gitlab-webhook"
  replication {
    auto {}
  }
}

resource "random_uuid" "random_webhook_secret" {}

resource "google_secret_manager_secret_version" "gitlab_webhook" {
  secret      = google_secret_manager_secret.gitlab_webhook.id
  secret_data = random_uuid.random_webhook_secret.result
}

# Firewall Rules
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = var.network_name
  project = var.project_id
  allow {
    ports    = [22]
    protocol = "tcp"
  }
  source_ranges = ["35.199.192.0/19"]
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = var.network_name
  project = var.project_id
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["git-vm"]
}

# Service Directory & DNS for Private Access
resource "google_service_directory_namespace" "gitlab" {
  provider     = google-beta
  namespace_id = "gitlab-namespace"
  location     = "us-central1"
  project      = var.project_id
}

resource "google_service_directory_service" "gitlab" {
  provider   = google-beta
  service_id = "gitlab"
  namespace  = google_service_directory_namespace.gitlab.id
}

resource "google_service_directory_endpoint" "gitlab" {
  provider    = google-beta
  endpoint_id = "endpoint"
  service     = google_service_directory_service.gitlab.id
  network     = var.network_id
  address     = google_compute_instance.default.network_interface[0].network_ip
  port        = 443
}

resource "google_dns_managed_zone" "sd_zone" {
  provider    = google-beta
  name        = "peering-zone"
  dns_name    = "example.com."
  description = "Private DNS Service Directory zone for Gitlab Instance"
  project     = var.project_id
  visibility  = "private"

  service_directory_config {
    namespace {
      namespace_url = google_service_directory_namespace.gitlab.id
    }
  }
  private_visibility_config {
    networks {
      network_url = local.gitlab_network_url
    }
  }
}
