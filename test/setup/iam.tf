/**
 * Copyright 2019 Google LLC
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

locals {
  int_required_roles = [
    "roles/artifactregistry.admin",
    "roles/binaryauthorization.attestorsAdmin",
    "roles/cloudbuild.builds.builder",
    "roles/cloudbuild.workerPoolOwner",
    "roles/cloudbuild.admin",
    "roles/clouddeploy.admin",
    "roles/cloudkms.admin",
    "roles/cloudkms.publicKeyViewer",
    "roles/containeranalysis.notes.editor",
    "roles/compute.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/gkehub.editor",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/pubsub.editor",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/source.admin",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/viewer",
    "roles/secretmanager.admin",
    "roles/servicedirectory.admin",
    "roles/dns.admin"
  ]
  gke_int_required_roles = [
    "roles/compute.networkAdmin",
    "roles/container.admin",
    "roles/binaryauthorization.policyEditor",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/serviceusage.serviceUsageViewer",
    "roles/iam.serviceAccountUser"
  ]
}

resource "google_service_account" "int_test" {
  project      = module.project_standalone.project_id
  account_id   = "ci-account"
  display_name = "ci-account"
}

resource "google_service_account_key" "int_test" {
  service_account_id = google_service_account.int_test.id
}

resource "google_project_iam_member" "int_test_singleproj" {
  for_each = toset(local.int_required_roles)

  project = module.project_standalone.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_project_iam_member" "gke_int_test_singleproj" {
  for_each = toset(local.gke_int_required_roles)

  project = module.project_standalone.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "org_iam_member" {
  role   = "roles/resourcemanager.organizationAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
  org_id = var.org_id
}

resource "google_organization_iam_member" "organizationServiceAgent_role" {
  org_id = var.org_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "organization_xpn_role" {
  org_id = var.org_id
  role   = "roles/compute.xpnAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "orgPolicyAdmin_role" {
  org_id = var.org_id
  role   = "roles/orgpolicy.policyAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_organization_iam_member" "policyAdmin_role" {
  org_id = var.org_id
  role   = "roles/accesscontextmanager.policyAdmin"
  member = "serviceAccount:${google_service_account.int_test.email}"
}
