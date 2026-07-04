output "control_plane_public_ip" {
  value = google_compute_instance.control_plane.network_interface[0].access_config[0].nat_ip
}

output "control_plane_private_ip" {
  value = var.control_plane_private_ip
}

output "worker_public_ips" {
  value = [for i in google_compute_instance.worker : i.network_interface[0].access_config[0].nat_ip]
}

output "worker_private_ips" {
  value = [for i in range(var.worker_count) : cidrhost(var.worker_ip_range, i + 20)]
}

output "worker_names" {
  value = [for i in google_compute_instance.worker : i.name]
}
