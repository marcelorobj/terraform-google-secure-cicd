/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_compute_global_address" "worker_range" {
  project       = var.project_id_standalone
  name          = "worker-pool-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.3.3.0"
  prefix_length = 24
  network       = module.vpc.network_name

}

resource "google_service_networking_connection" "gitlab_worker_pool_conn" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.worker_range.name]
  depends_on              = [google_project_service.servicenetworking]
}

resource "google_project_service" "servicenetworking" {
  project            = var.project_id_standalone
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloudbuild_worker_pool" "pool" {
  name     = "cb-pool"
  project  = var.project_id_standalone
  location = var.workpool_region
  worker_config {
    disk_size_gb   = 100
    machine_type   = var.workerpool_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network          = module.vpc.network_id
    peered_network_ip_range = "/24"
  }

  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn]
}

resource "time_sleep" "wait_service_network_peering" {
  depends_on = [google_service_networking_connection.gitlab_worker_pool_conn]

  create_duration = "30s"
}
