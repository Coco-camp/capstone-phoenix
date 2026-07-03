variable "cluster_name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "subnet_range" {
  type    = string
  default = "10.10.1.0/24"
}
