terraform {
  required_version = ">= 1.7"

  # Remote state — Terraform Cloud's free tier. GCP has its own native
  # remote-state option (a GCS bucket), which would also satisfy the
  # capstone's "S3 + DynamoDB or equivalent" requirement, but Terraform
  # Cloud is used here to keep state management decoupled from whichever
  # cloud happens to host the compute -- if you ever migrate providers again,
  # state storage doesn't move with it.
  #
  # Setup (one-time, do this before `terraform init`):
  #   1. Free account at https://app.terraform.io
  #   2. Organization + workspace named "capstone-phoenix", execution mode
  #      "Local" (state storage + locking only; apply still runs on your machine)
  #   3. `terraform login` to store an API token locally
  #   4. Replace the organization name below
  #
  # GCS-native alternative, if you'd rather keep everything in one cloud:
  #   backend "gcs" {
  #     bucket = "capstone-phoenix-tfstate"
  #     prefix = "terraform/state"
  #   }
  #   (create the bucket first: gcloud storage buckets create gs://capstone-phoenix-tfstate --location=us-central1)
  cloud {
    organization = "coco-camp"

    workspaces {
      name = "capstone-phoenix"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "google" {
  project     = var.gcp_project_id
  region      = var.region
  zone        = var.zone
  credentials = file(var.gcp_credentials_file)
}
