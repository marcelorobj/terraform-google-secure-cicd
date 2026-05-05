/**
 * Copyright 2026 Google LLC
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
  use_csr = var.repository_type == "CSR"
  repos   = local.use_csr ? {} : { for repo in [var.cd_repository] : repo.repository_name => repo }

  cd_repo_source = local.use_csr ? {
    uri        = "https://source.developers.google.com/p/${var.project_id}/r/${var.csr_cloudbuild_cd_repo}"
    repo_type  = "CLOUD_SOURCE_REPOSITORIES"
    repository = null
    } : {
    uri        = null
    repo_type  = var.repository_type == "GITHUB" ? var.repository_type : "UNKNOWN"
    repository = values(module.cloudbuild_repositories[0].cloud_build_repositories_2nd_gen_repositories)[0].id
  }
}
