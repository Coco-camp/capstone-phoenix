variable "gcp_project_id" {
  type        = string
  description = "Your GCP project ID, e.g. capstone-phoenix"
}

variable "gcp_credentials_file" {
  type        = string
  description = "Path to the service account JSON key, e.g. ~/.gcp/terraform-key.json"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "cluster_name" {
  type    = string
  default = "phoenix"
}

variable "admin_ip_cidr" {
  type        = string
  description = "Your public IP/32 for SSH access. Get it with: curl -s ifconfig.me"
}

variable "ssh_public_key" {
  type        = string
  description = "Your SSH public key contents."
}

variable "worker_count" {
  type    = number
  default = 2
}
