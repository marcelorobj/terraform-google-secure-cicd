variable "project_id" {
  description = "The project id where Gitlab will run."
  type        = string
}

variable "network_name" {
  description = "The network name where Gitlab will run."
  type        = string
}

variable "network_id" {
  description = "The network id where Gitlab will run."
  type        = string
}

variable "cloud_build_sa" {
  description = "Cloud Build Service Account email to be granted Encrypt/Decrypt role."
  type        = string
}

variable "seed_project_number" {
  description = "The seed project number."
  type        = string
}