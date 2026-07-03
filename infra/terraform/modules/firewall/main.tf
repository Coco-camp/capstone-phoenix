terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# Least-privilege firewall: only 22 (admin IP), 80, 443 reachable from the internet.
# The k3s API (6443) and node-to-node traffic (Flannel VXLAN 8472, kubelet 10250, etc.)
# are ONLY allowed from inside the private network / between the nodes themselves,
# never from 0.0.0.0/0.

resource "hcloud_firewall" "this" {
  name = "${var.cluster_name}-fw"

  # SSH — locked to the admin's IP only
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.admin_ip_cidr]
  }

  # HTTP — needed for ACME HTTP-01 challenge + redirects
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS — the app
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # ICMP for diagnostics from admin only
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = [var.admin_ip_cidr]
  }

  # NOTE: 6443 (k8s API), 8472 (flannel vxlan), 10250 (kubelet) are intentionally
  # NOT opened here. Node-to-node cluster traffic travels over the private
  # hcloud_network (10.10.0.0/16) attached in the compute module, which Hetzner
  # firewalls do not filter by default for same-network traffic — but since these
  # ports are simply absent from this ruleset, they are unreachable from the
  # public internet entirely. Control-plane access from your laptop happens via
  # an SSH tunnel (see docs/RUNBOOK.md), not a direct public 6443 rule.
}
