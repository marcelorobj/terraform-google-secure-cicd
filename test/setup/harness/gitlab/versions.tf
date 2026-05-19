terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.6 , < 8"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.6, < 8"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
  }
}
