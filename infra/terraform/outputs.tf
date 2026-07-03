output "control_plane_public_ip" {
  value = module.compute.control_plane_public_ip
}

output "worker_public_ips" {
  value = module.compute.worker_public_ips
}

output "ssh_control_plane" {
  value = "ssh deploy@${module.compute.control_plane_public_ip}"
}
