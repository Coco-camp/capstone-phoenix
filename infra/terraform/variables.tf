variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token. Set via TF_VAR_hcloud_token env var — never commit it."
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
