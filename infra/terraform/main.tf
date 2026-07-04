module "network" {
  source       = "./modules/network"
  cluster_name = var.cluster_name
  region       = var.region
}

module "firewall" {
  source        = "./modules/firewall"
  cluster_name  = var.cluster_name
  network_name  = module.network.network_name
  subnet_range  = "10.10.1.0/24"
  admin_ip_cidr = var.admin_ip_cidr
}

module "compute" {
  source         = "./modules/compute"
  cluster_name   = var.cluster_name
  ssh_public_key = var.ssh_public_key
  subnet_name    = module.network.subnet_name
  target_tag     = module.firewall.target_tag
  zone           = var.zone
  worker_count   = var.worker_count
}

# Renders a ready-to-use Ansible inventory from Terraform outputs.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  content  = <<-EOT
    # ansible_user=deploy because the compute module injects an SSH key via
    # GCP instance metadata in the form "deploy:<pubkey>", which auto-creates
    # a sudo-enabled "deploy" user on first boot -- no separate bootstrap-as-
    # root step needed like on providers that only ship a bare root account.
    [control_plane]
    ${module.compute.control_plane_public_ip} private_ip=${module.compute.control_plane_private_ip} ansible_user=deploy

    [workers]
    %{ for idx, ip in module.compute.worker_public_ips ~}
    ${ip} private_ip=${module.compute.worker_private_ips[idx]} ansible_user=deploy
    %{ endfor ~}

    [k3s_cluster:children]
    control_plane
    workers
  EOT
}
