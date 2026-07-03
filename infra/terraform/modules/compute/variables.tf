variable "cluster_name" {
  type = string
}

variable "ssh_public_key" {
  type        = string
  description = "Contents of your ~/.ssh/id_ed25519.pub"
}

variable "subnet_name" {
  type = string
}

variable "target_tag" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

# e2-medium (2 vCPU / 4GB) for control-plane -- it also runs Traefik,
# cert-manager, and Argo CD alongside the k3s server, so it needs headroom.
variable "control_plane_machine_type" {
  type    = string
  default = "e2-medium"
}

# e2-small (2 vCPU / 2GB) for workers -- cheapest type that comfortably runs
# 2+ app replicas per tier.
variable "worker_machine_type" {
  type    = string
  default = "e2-small"
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
