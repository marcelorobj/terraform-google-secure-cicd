/**
 * Copyright 2022 Google LLC
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

variable "project_id" {
  type        = string
  description = "Project ID in which all resources will be deployed"
}

variable "region" {
  type        = string
  description = "Location in which all regional resources will be deployed"
  default     = "us-central1"
}

variable "app_name" {
  type        = string
  description = "Name of intended deployed application; to be used as a prefix for certain resources"
  default     = "my-app"
}

variable "env1_name" {
  type        = string
  description = "Name of environment 1"
  default     = "dev"
}

variable "repo_type" {
  type        = string
  description = "Name of environment 1"
  default     = "CSR"
}

variable "github_auth" {
  type = object({
    secret_id         = string
    app_id_secret_id  = string
    secret_project_id = string
  })
  description = "Authentication configuration for GitHub. Required only if repo_type is 'GITHUBv2'."
  default     = null
}

variable "ci_repository" {
  type = object({
    repository_name = string
    repository_url  = string
  })
  description = "The CI repository to configure. The key is a short name for the service."
  default     = null
}

variable "cd_repository" {
  type = object({
    repository_name = string
    repository_url  = string
  })
  description = "The CI repository to configure. The key is a short name for the service."
  default     = null
}

variable "env2_name" {
  type        = string
  description = "Name of environment 2"
  default     = "qa"
}

variable "env3_name" {
  type        = string
  description = "Name of environment 3"
  default     = "prod"
}

variable "cloudbuild_private_pool_machine_type" {
  type        = string
  description = "Machine type for Cloud Build private pool"
  default     = "e2-medium"
}

variable "labels" {
  description = "A set of key/value label pairs to assign to the resources deployed by this blueprint."
  type        = map(string)
  default     = {}
}
