variable "cluster_name" {
  type = string
}

variable "ssh_public_key" {
  type        = string
  description = "Contents of your ~/.ssh/id_ed25519.pub"
}

variable "network_id" {
  type = string
}

variable "firewall_id" {
  type = string
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

variable "location" {
  type    = string
  default = "nbg1" # Nuremberg — cheapest EU zone
}

variable "control_plane_type" {
  type    = string
  default = "cpx21" # 3 vCPU / 4GB — k3s server needs a bit more headroom
}

variable "worker_type" {
  type    = string
  default = "cpx11" # 2 vCPU / 2GB — cheapest usable worker
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "control_plane_private_ip" {
  type    = string
  default = "10.10.1.10"
}

variable "worker_ip_range" {
  type    = string
  default = "10.10.1.0/24"
}
