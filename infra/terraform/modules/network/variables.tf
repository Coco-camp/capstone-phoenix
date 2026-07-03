variable "cluster_name" {
  type = string
}

variable "ip_range" {
  type    = string
  default = "10.10.0.0/16"
}

variable "subnet_range" {
  type    = string
  default = "10.10.1.0/24"
}

variable "network_zone" {
  type    = string
  default = "eu-central"
}
