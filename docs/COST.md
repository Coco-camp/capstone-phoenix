# Cost — Phoenix

All prices GCP `us-central1`, monthly, as configured in
`infra/terraform/modules/compute/variables.tf`. This project runs on the
$300 / 90-day GCP free trial credit -- during the capstone window, actual
out-of-pocket cost is $0. The table below is what it WOULD cost if the
credit weren't applied, since a real deployment eventually needs a real
budget and the capstone asks for an honest number either way.

| Resource | Type | Qty | Approx $/mo each | Approx $/mo total |
|---|---|---|---|---|
| Control-plane | e2-medium (2 vCPU / 4GB) | 1 | ~24.50 | 24.50 |
| Worker | e2-small (2 vCPU / 2GB) | 2 | ~12.25 | 24.50 |
| VPC + subnet | -- | 1 | free | 0 |
| Firewall rules | -- | 3 | free | 0 |
| External IPs (ephemeral) | -- | 3 | free while attached | 0 |
| Boot disks | 20GB standard persistent disk | 3 | ~0.80 | 2.40 |
| **Total infra** | | | | **~$51.40/mo** |
| Domain (annual, amortized) | e.g. Cloudflare/Namecheap | 1 | ~0.80 | 0.80 |
| **Grand total** | | | | **~$52.20/mo (billed against free credit during capstone)** |

## Why this is pricier than the Hetzner estimate we started with

GCP's smallest general-purpose instances (`e2-small`/`e2-medium`) run
roughly 2-3x Hetzner's equivalent `cpx` tier for similar specs -- the
trade-off made deliberately here: the free $300 credit makes this a genuine
$0 cost for the 3-week capstone window, and GCP's amd64-native instances
needed zero changes to the already-published `taskapp-backend`/
`taskapp-frontend` images (Hetzner's cheaper price would have required an
ARM rebuild if using a free ARM-tier alternative, or been just as amd64-
priced anyway). Cost was a real factor, but "don't touch working images" and
"stay within a free tier" outweighed shaving a few dollars off an already-
free bill.

## How to cut this in half (relevant once the credit runs out / for a real deployment)

Switching all three nodes to `e2-small` (2 vCPU / 2GB) instead of
`e2-medium` for the control-plane saves ~$12/mo (~24% of total infra cost) --
the control-plane's extra headroom exists specifically to run Traefik,
cert-manager, and Argo CD alongside k3s comfortably; on `e2-small` that
platform tooling would compete with the k3s server itself under load, which
is the same kind of contention the capstone's resource requests/limits are
meant to catch before it causes an outage. A second lever: GCP committed-use
discounts (1-3 year commitment) cut compute cost 20-40%, but don't make
sense during a 3-week capstone -- only worth it for a genuinely long-lived
deployment.
