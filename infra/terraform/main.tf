module "network" {
  source       = "./modules/network"
  cluster_name = var.cluster_name
}

module "firewall" {
  source        = "./modules/firewall"
  cluster_name  = var.cluster_name
  admin_ip_cidr = var.admin_ip_cidr
}

module "compute" {
  source         = "./modules/compute"
  cluster_name   = var.cluster_name
  ssh_public_key = var.ssh_public_key
  network_id     = module.network.network_id
  firewall_id    = module.firewall.firewall_id
  worker_count   = var.worker_count

  depends_on = [module.network.subnet_id]
}

# Renders a ready-to-use Ansible inventory from Terraform outputs, so there's
# never a manual copy/paste step of IPs between infra and cluster bring-up.
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  content  = <<-EOT
    # ansible_user=root because Hetzner Ubuntu images only have root by
    # default. The hardening role creates a non-root "deploy" sudo user with
    # key-only SSH for manual admin access, disables root SSH login, and
    # disables password auth cluster-wide — Ansible orchestration itself
    # continues over root's key since that's the only account that exists
    # pre-hardening. See docs/RUNBOOK.md for manual login as "deploy" after
    # the hardening role runs.
    [control_plane]
    ${module.compute.control_plane_public_ip} private_ip=${module.compute.control_plane_private_ip} ansible_user=root

    [workers]
    %{ for idx, ip in module.compute.worker_public_ips ~}
    ${ip} private_ip=${module.compute.worker_private_ips[idx]} ansible_user=root
    %{ endfor ~}

    [k3s_cluster:children]
    control_plane
    workers
  EOT
}

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
