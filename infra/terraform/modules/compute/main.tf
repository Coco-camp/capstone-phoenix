terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  # GCP's metadata-based SSH key format is "username:public-key-content".
  # This is what creates the "deploy" user automatically on first boot --
  # no separate user-creation step needed like on Hetzner's bare images.
  ssh_metadata = "deploy:${var.ssh_public_key}"
}

resource "google_compute_instance" "control_plane" {
  name         = "${var.cluster_name}-cp-1"
  machine_type = var.control_plane_machine_type
  zone         = var.zone
  tags         = [var.target_tag]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 20
    }
  }

  network_interface {
    subnetwork = var.subnet_name
    network_ip = var.control_plane_private_ip
    access_config {} # ephemeral public IP
  }

  metadata = {
    ssh-keys = local.ssh_metadata
  }

  labels = {
    role    = "control-plane"
    cluster = var.cluster_name
  }
}

resource "google_compute_instance" "worker" {
  count        = var.worker_count
  name         = "${var.cluster_name}-worker-${count.index + 1}"
  machine_type = var.worker_machine_type
  zone         = var.zone
  tags         = [var.target_tag]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 20
    }
  }

  network_interface {
    subnetwork = var.subnet_name
    network_ip = cidrhost(var.worker_ip_range, count.index + 10)
    access_config {}
  }

  metadata = {
    ssh-keys = local.ssh_metadata
  }

  labels = {
    role    = "worker"
    cluster = var.cluster_name
  }
}
