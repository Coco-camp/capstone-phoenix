terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

resource "hcloud_ssh_key" "this" {
  name       = "${var.cluster_name}-key"
  public_key = var.ssh_public_key
}

resource "hcloud_server" "control_plane" {
  name        = "${var.cluster_name}-cp-1"
  server_type = var.control_plane_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.this.id]
  firewall_ids = [var.firewall_id]

  network {
    network_id = var.network_id
    ip         = var.control_plane_private_ip
  }

  labels = {
    role    = "control-plane"
    cluster = var.cluster_name
  }

  # Ensure the server only boots once it's attached to the private network,
  # otherwise the private NIC can come up after cloud-init runs.
  depends_on = [var.network_id]
}

resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  server_type = var.worker_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.this.id]
  firewall_ids = [var.firewall_id]

  network {
    network_id = var.network_id
    ip         = cidrhost(var.worker_ip_range, count.index + 10)
  }

  labels = {
    role    = "worker"
    cluster = var.cluster_name
  }

  depends_on = [var.network_id]
}
