terraform {
  required_version = ">= 1.7"

  # Remote state — Terraform Cloud's free tier, since we're on Hetzner (no AWS
  # account required). This is the "or equivalent for your provider" option the
  # capstone README calls out in place of S3 + DynamoDB.
  #
  # Setup (one-time, do this before `terraform init`):
  #   1. Create a free account at https://app.terraform.io
  #   2. Create an organization (e.g. "collins-devops") and a workspace named
  #      "capstone-phoenix" with execution mode "Local" (so `terraform apply`
  #      still runs on your machine, TFC just stores state + locks it).
  #   3. `terraform login` to store an API token locally.
  #   4. Replace the organization name below.
  #
  # If you'd rather use S3 + DynamoDB directly (e.g. you already have an AWS
  # account), swap this block for:
  #   backend "s3" {
  #     bucket         = "collins-capstone-phoenix-tfstate"
  #     key            = "capstone-phoenix/terraform.tfstate"
  #     region         = "eu-central-1"
  #     dynamodb_table = "capstone-phoenix-tf-lock"
  #     encrypt        = true
  #   }
  # Either way: this file, once filled in, is safe to commit — it holds no
  # secrets, only where state lives.
  cloud {
    organization = "CHANGE_ME_ORG"

    workspaces {
      name = "capstone-phoenix"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
