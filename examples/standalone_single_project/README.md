# Standalone Single Project CI/CD example

This end-to-end example showcases the [`secure-ci`](https://github.com/GoogleCloudPlatform/terraform-google-secure-cicd/tree/main/modules/secure-ci) and [`secure-cd`](https://github.com/GoogleCloudPlatform/terraform-google-secure-cicd/tree/main/modules/secure-cd) modules working together to create a secure software build and deploy pipeline.

This example also deploys the [`cloudbuild-private-pool`](https://github.com/GoogleCloudPlatform/terraform-google-secure-cicd/tree/main/modules/cloudbuild-private-pool) module to enable deploying to private GKE clusters from Cloud Build.

For simplified deployment and demonstration purposes, this blueprint creates GKE clusters and accompanying VPC networks for multiple sample environments (dev, qa, prod) within a single Google Cloud project.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| app\_name | Name of intended deployed application; to be used as a prefix for certain resources | `string` | `"ci-cd"` | no |
| cd\_repository | The CI repository to configure. The key is a short name for the service. | <pre>object({<br>    repository_name = string<br>    repository_url  = string<br>  })</pre> | `null` | no |
| ci\_repository | The CI repository to configure. The key is a short name for the service. | <pre>object({<br>    repository_name = string<br>    repository_url  = string<br>  })</pre> | `null` | no |
| cloudbuild\_private\_pool\_machine\_type | Machine type for Cloud Build private pool | `string` | `"e2-medium"` | no |
| env1\_name | Name of environment 1 | `string` | `"dev"` | no |
| env2\_name | Name of environment 2 | `string` | `"qa"` | no |
| env3\_name | Name of environment 3 | `string` | `"prod"` | no |
| github\_auth | Authentication configuration for GitHub. Required only if repo\_type is 'GITHUBv2'. | <pre>object({<br>    secret_id         = string<br>    app_id_secret_id  = string<br>    secret_project_id = string<br>  })</pre> | `null` | no |
| gitlab\_auth | Authentication configuration for GitLab. Required only if repo\_type is 'GITLABv2'. | <pre>object({<br>    read_authorizer_credential_secret_id = string<br>    authorizer_credential_secret_id      = string<br>    webhook_secret_id                    = string<br>    enterprise_host_uri                  = optional(string)<br>    enterprise_service_directory         = optional(string)<br>    enterprise_ca_certificate            = optional(string)<br>    secret_project_id                    = string<br>  })</pre> | `null` | no |
| labels | A set of key/value label pairs to assign to the resources deployed by this blueprint. | `map(string)` | `{}` | no |
| network\_name | Optional vpc network name if using already existing vpc | `any` | `null` | no |
| private\_worker\_pool\_id | Optional private worker pool id if using already existing worker pool | `any` | `null` | no |
| project\_id | Project ID in which all resources will be deployed | `string` | n/a | yes |
| region | Location in which all regional resources will be deployed | `string` | `"us-central1"` | no |
| repository\_type | Repository type, e.g. GITHUB or GITLAB | `string` | `"GITLAB"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cd\_repo\_name | The name of the CD repository. |
| cd\_repo\_url | The URL of the CD repository. |
| ci\_repo\_name | The name of the CI repository. |
| ci\_repo\_url | The URL of the CI repository. |
| clouddeploy\_pipeline\_id | ID of the Cloud Deploy delivery pipeline |
| cluster\_names | Comma-separated names of the deployed GKE clusters |
| console\_walkthrough\_link | n/a |
| gar\_repo | Artifact Registry repo |
| gitlab\_url | The URL of the GitLab instance. |
| neos\_tutorial\_url | n/a |
| project\_id | Project ID |
| region | Region |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
