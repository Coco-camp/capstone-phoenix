variable "cluster_name" {
  type = string
}

variable "admin_ip_cidr" {
  type        = string
  description = "Your public IP in CIDR form, e.g. 203.0.113.4/32. Get it with: curl -s ifconfig.me"
}
