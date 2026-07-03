# Cost — Phoenix

All prices Hetzner Cloud, Nuremberg (nbg1), monthly, as configured in
`infra/terraform/modules/compute/variables.tf`. Verify current prices at
https://www.hetzner.com/cloud before submitting — Hetzner adjusts pricing
periodically.

| Resource | Type | Qty | Approx €/mo each | Approx €/mo total |
|---|---|---|---|---|
| Control-plane | cpx21 (3 vCPU / 4GB / 80GB) | 1 | ~8.50 | 8.50 |
| Worker | cpx11 (2 vCPU / 2GB / 40GB) | 2 | ~4.50 | 9.00 |
| Private network | — | 1 | free | 0 |
| Firewall | — | 1 | free | 0 |
| IPv4 addresses | included with servers | 3 | included | 0 |
| Volumes (PVC, local-path) | included in server disk | — | included | 0 |
| **Total infra** | | | | **~€17.50/mo** |
| Domain (annual, amortized) | e.g. Cloudflare/Namecheap | 1 | ~0.80 | 0.80 |
| **Grand total** | | | | **~€18.30/mo** |

(≈ $19–20/mo at typical EUR/USD rates — check current rate for your report.)

## How to cut this in half

The single biggest lever is the control-plane size: `cpx21` (€8.50) is nearly
half the bill by itself, chosen for headroom to also run Traefik,
cert-manager, and Argo CD alongside the k3s server. Dropping to `cpx11`
(€4.50) for the control-plane and moving Argo CD's slightly heavier workload
onto a worker instead would save ~€4/mo (~22% of total infra cost) — the
trade-off is a more crowded control-plane node during any period the extra
workers are also under load, which is exactly the kind of contention this
capstone's resource requests/limits are meant to catch before it becomes an
outage. A second lever: workers at `cpx11` are already Hetzner's cheapest
usable tier for running 2 app tiers + surviving one node's pods rescheduling
onto the survivor, so further shrinking there risks failing the "app stays up
when a worker dies" requirement rather than saving meaningfully.
