terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # This tree is a validate-only blueprint; when deployed, state would live in
  # a versioned GCS bucket so applies lock and history survives any one machine.
  # backend "gcs" {
  #   bucket = "platform-terraform-state"
  #   prefix = "envs/staging/gcp"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
