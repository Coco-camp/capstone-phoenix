output "control_plane_public_ip" {
  value = hcloud_server.control_plane.ipv4_address
}

output "control_plane_private_ip" {
  value = var.control_plane_private_ip
}

output "worker_public_ips" {
  value = [for s in hcloud_server.worker : s.ipv4_address]
}

output "worker_private_ips" {
  value = [for i in range(var.worker_count) : cidrhost(var.worker_ip_range, i + 10)]
}

output "worker_names" {
  value = [for s in hcloud_server.worker : s.name]
}
