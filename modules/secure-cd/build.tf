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

# Set up Cloud Deploy notifications
# (https://cloud.google.com/deploy/docs/subscribe-deploy-notifications)

resource "google_pubsub_topic" "clouddeploy_topic" {
  name    = local.clouddeploy_pubsub_topic_name
  project = var.project_id
  labels  = var.labels
}

resource "google_cloudbuild_trigger" "deploy_trigger_gitlab" {
  for_each = var.repository_type == "GITLAB" ? {
    for env, config in var.deploy_branch_clusters : env => config
    if config.next_env != ""
  } : {}

  project         = var.project_id
  location        = var.primary_location
  name            = "deploy-trigger-gitlab-${each.key}"
  service_account = "projects/${var.project_id}/serviceAccounts/${var.cloudbuild_service_account}"

  pubsub_config {
    topic = google_pubsub_topic.clouddeploy_topic.id
  }

  substitutions = merge(
    {
      _GAR_REPOSITORY            = var.gar_repo_name
      _DEFAULT_REGION            = each.value.location
      _CLUSTER_NAME              = each.value.cluster
      _ANTHOS_MEMBERSHIP         = each.value.anthos_membership
      _TARGET_TYPE               = each.value.target_type
      _CLUSTER_PROJECT           = each.value.project_id
      _CLOUDBUILD_FILENAME       = var.app_deploy_trigger_yaml
      _CACHE_BUCKET_NAME         = var.cache_bucket_name
      _NEXT_ENV                  = each.value.next_env
      _ATTESTOR_NAME             = each.value.env_attestation
      _CLOUDBUILD_PRIVATE_POOL   = var.cloudbuild_private_pool
      _CLOUDDEPLOY_PIPELINE_NAME = var.clouddeploy_pipeline_name
      _GITLAB_CA_CERT            = var.gitlab_auth != null ? var.gitlab_auth.enterprise_ca_certificate : ""
      _GITLAB_HOST_URI           = var.gitlab_auth != null ? var.gitlab_auth.enterprise_host_uri : ""
      _GITLAB_PAT_SECRET_ID      = var.gitlab_auth != null ? var.gitlab_auth.authorizer_credential_secret_id : ""
      _GITLAB_SECRET_PROJECT     = var.gitlab_auth != null ? var.gitlab_auth.secret_project_id : ""
      _CD_REPO_URL               = var.cd_repository.repository_url
      _ACTION_TYPE               = "$(body.message.attributes.Action)"
      _RESOURCE_TYPE             = "$(body.message.attributes.ResourceType)"
      _DELIVERY_PIPELINE_ID      = "$(body.message.attributes.DeliveryPipelineId)"
      _TARGET_ID                 = "$(body.message.attributes.TargetId)"
      _RELEASE_ID                = "$(body.message.attributes.ReleaseId)"
    },
    var.additional_substitutions
  )

  build {
    timeout     = "3600s"
    tags        = ["secure-cicd-cd", "gitlab-parent-trigger"]
    logs_bucket = "gs://$_CACHE_BUCKET_NAME/build_logs"

    options {
      substitution_option = "ALLOW_LOOSE"
      worker_pool         = var.cloudbuild_private_pool
    }

    available_secrets {
      secret_manager {
        env          = "_GITLAB_TOKEN"
        version_name = "$_GITLAB_PAT_SECRET_ID/versions/latest"
      }
    }

    step {
      name       = "gcr.io/cloud-builders/gcloud"
      id         = "manual-fetch-source"
      entrypoint = "bash"
      secret_env = ["_GITLAB_TOKEN"]
      args = [
        "-c",
        <<-EOT
          if [ -n "$_GITLAB_CA_CERT" ]; then
            echo "Configuring git with GitLab CA certificate..."
            echo "$_GITLAB_CA_CERT" > /tmp/gitlab-ca.crt
            _GITLAB_HOST=$$(echo "$_GITLAB_HOST_URI" | sed 's|https://||g')
            git config --global "http.https://$$_GITLAB_HOST/.sslCAInfo" /tmp/gitlab-ca.crt
            echo "GitLab CA certificate configured."
          fi

          _GITLAB_HOST=$$(echo "$_GITLAB_HOST_URI" | sed 's|https://||g')
          _REPO_PATH=$$(echo "$_CD_REPO_URL" | sed "s|https://$$_GITLAB_HOST/||g")

          _AUTH_URL="https://oauth2:$$_GITLAB_TOKEN@$$_GITLAB_HOST/$$_REPO_PATH"

          echo "Cloning repository..."
          git clone "$$_AUTH_URL" /workspace
          cd /workspace
          git checkout main

          echo "Submitting child build using $_CLOUDBUILD_FILENAME..."

          _SUBS="_GAR_REPOSITORY=$_GAR_REPOSITORY"
          _SUBS+=",_DEFAULT_REGION=$_DEFAULT_REGION"
          _SUBS+=",_CLUSTER_NAME=$_CLUSTER_NAME"
          _SUBS+=",_ANTHOS_MEMBERSHIP=$_ANTHOS_MEMBERSHIP"
          _SUBS+=",_TARGET_TYPE=$_TARGET_TYPE"
          _SUBS+=",_CLUSTER_PROJECT=$_CLUSTER_PROJECT"
          _SUBS+=",_CLOUDBUILD_FILENAME=$_CLOUDBUILD_FILENAME"
          _SUBS+=",_CACHE_BUCKET_NAME=$_CACHE_BUCKET_NAME"
          _SUBS+=",_NEXT_ENV=$_NEXT_ENV"
          _SUBS+=",_ATTESTOR_NAME=$_ATTESTOR_NAME"
          _SUBS+=",_CLOUDBUILD_PRIVATE_POOL=$_CLOUDBUILD_PRIVATE_POOL"
          _SUBS+=",_CLOUDDEPLOY_PIPELINE_NAME=$_CLOUDDEPLOY_PIPELINE_NAME"
          _SUBS+=",_ACTION_TYPE=$_ACTION_TYPE"
          _SUBS+=",_RESOURCE_TYPE=$_RESOURCE_TYPE"
          _SUBS+=",_DELIVERY_PIPELINE_ID=$_DELIVERY_PIPELINE_ID"
          _SUBS+=",_TARGET_ID=$_TARGET_ID"
          _SUBS+=",_RELEASE_ID=$_RELEASE_ID"

          %{for k, v in var.additional_substitutions~}
          _SUBS+=",${k}=$$${k}"
          %{endfor~}

          gcloud builds submit \
            --service-account="projects/${var.project_id}/serviceAccounts/${var.cloudbuild_service_account}" \
            --config=$_CLOUDBUILD_FILENAME \
            --region=$_DEFAULT_REGION \
            --substitutions="$$_SUBS" \
            --project=${var.project_id}
        EOT
      ]
    }
  }

  filter = "_RESOURCE_TYPE.matches('Rollout') && _ACTION_TYPE.matches('Succeed') && _DELIVERY_PIPELINE_ID.matches('${var.clouddeploy_pipeline_name}') && _TARGET_ID.matches('${google_clouddeploy_target.deploy_target[each.key].name}')"
}




resource "google_cloudbuild_trigger" "deploy_trigger" {
  for_each = var.repository_type != "GITLAB" ? {
    for env, config in var.deploy_branch_clusters : env => config
    if config.next_env != ""
  } : {}


  project  = var.project_id
  location = var.primary_location
  name     = each.value.target_type == "gke" ? "deploy-trigger-${each.value.cluster}" : each.value.target_type == "anthos_cluster" ? "deploy-trigger-${each.value.anthos_membership}" : "deploy-trigger-${each.key}"
  filename = "cloudbuild-cd.yaml"

  service_account = "projects/${var.project_id}/serviceAccounts/${var.cloudbuild_service_account}"

  pubsub_config {
    topic = google_pubsub_topic.clouddeploy_topic.id
  }

  source_to_build {
    ref        = "main"
    repo_type  = local.cd_repo_source.repo_type
    repository = local.cd_repo_source.repository
  }

  substitutions = merge(
    {
      _GAR_REPOSITORY            = var.gar_repo_name
      _DEFAULT_REGION            = each.value.location
      _CLUSTER_NAME              = each.value.cluster
      _ANTHOS_MEMBERSHIP         = each.value.anthos_membership
      _TARGET_TYPE               = each.value.target_type
      _CLUSTER_PROJECT           = each.value.project_id
      _CLOUDBUILD_FILENAME       = var.app_deploy_trigger_yaml
      _CACHE_BUCKET_NAME         = var.cache_bucket_name
      _NEXT_ENV                  = each.value.next_env
      _ATTESTOR_NAME             = each.value.env_attestation
      _CLOUDBUILD_PRIVATE_POOL   = var.cloudbuild_private_pool
      _CLOUDDEPLOY_PIPELINE_NAME = var.clouddeploy_pipeline_name
      # Substitutions to parse incoming Pub/sub messages from Cloud Deploy
      _ACTION_TYPE          = "$(body.message.attributes.Action)"
      _RESOURCE_TYPE        = "$(body.message.attributes.ResourceType)"
      _DELIVERY_PIPELINE_ID = "$(body.message.attributes.DeliveryPipelineId)"
      _TARGET_ID            = "$(body.message.attributes.TargetId)"
      _RELEASE_ID           = "$(body.message.attributes.ReleaseId)"
    },
    var.additional_substitutions
  )

  filter = "_RESOURCE_TYPE.matches('Rollout') && _ACTION_TYPE.matches('Succeed') && _DELIVERY_PIPELINE_ID.matches('${var.clouddeploy_pipeline_name}') && _TARGET_ID.matches('${google_clouddeploy_target.deploy_target[each.key].name}')"
}
