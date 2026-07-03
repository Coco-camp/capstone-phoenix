terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Least-privilege firewall: only 22 (admin IP), 80, 443 reachable from the
# internet. GCP firewalls are default-deny-ingress already (unlike AWS's
# default-allow-within-VPC), so we only need to declare the allows — there's
# no separate "deny all else" rule to write.
#
# The k3s API (6443) and node-to-node traffic (Flannel VXLAN 8472, kubelet
# 10250, etc.) are only allowed from within this VPC's own subnet, never from
# 0.0.0.0/0 — enforced by the allow-internal rule below being scoped to
# source_ranges = [subnet_range], not the internet.

resource "google_compute_firewall" "ssh" {
  name    = "${var.cluster_name}-allow-ssh"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_ip_cidr]
  target_tags   = ["${var.cluster_name}-node"]
}

resource "google_compute_firewall" "http_https" {
  name    = "${var.cluster_name}-allow-http-https"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.cluster_name}-node"]
}

resource "google_compute_firewall" "internal" {
  name    = "${var.cluster_name}-allow-internal"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  # Only nodes in our own subnet — this is what keeps 6443/8472/10250 off
  # the public internet while still letting cluster nodes talk to each other.
  source_ranges = [var.subnet_range]
  target_tags   = ["${var.cluster_name}-node"]
}
