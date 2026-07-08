# Phoenix — TaskApp on real Kubernetes

Capstone submission for `ts-a-devops/capstone-phoenix`. TaskApp
(React/nginx + Flask/Postgres) running highly-available, autoscaling,
zero-downtime, on a 3-node k3s cluster on Google Cloud Platform, behind
real HTTPS (Let's Encrypt) on a live domain, entirely GitOps-owned via
Argo CD.

Live at: **https://collins-phoenix.duckdns.org**

(Originally scoped for Hetzner; switched to GCP since the published app
images are amd64-only and GCP's free trial credit covers the full
capstone window at $0 — see `docs/COST.md`.)

## Layout

```
infra/terraform/   3-node GCP cluster: network, firewall, compute
infra/ansible/     k3s bring-up: hardening, k3s server, k3s agent roles
manifests/base/    all K8s resources (kustomize base)
manifests/overlays/prod/   pinned image digests — the only place you bump a release
gitops/            the one Argo CD Application you kubectl apply, once
docs/              ARCHITECTURE.md, RUNBOOK.md, COST.md, EVIDENCE/
```

## Start here

**`docs/RUNBOOK.md`** — every command, in order, from zero to a live,
GitOps-managed cluster. **`docs/ARCHITECTURE.md`** — the "why" behind
every design decision, including several real bugs found and fixed
during the build (documented honestly, not glossed over).

## Status — all Core, GitOps, and 3 Advanced items done and proven live

- [x] `terraform apply` — 3 nodes up, remote state (Terraform Cloud),
      least-priv firewall (22/80/443 only, 6443 never exposed)
- [x] `ansible-playbook playbook.yml` — `kubectl get nodes` all Ready,
      idempotent
- [x] cert-manager + Argo CD + metrics-server installed
- [x] Secret applied manually (documented, see `secret.example.yaml`)
- [x] Real image digests + real domain, all live
- [x] `gitops/application.yaml` applied — Argo CD **Synced + Healthy**
- [x] Core §4 checklist — every box demonstrated with evidence:
      namespace/ConfigMap/Secret split, Postgres+PVC (data survival
      proven live), 2+ replicas per tier spread across nodes, migration
      Job (not in entrypoint), liveness/readiness/startup probes,
      resource requests/limits, zero-downtime rolling update (proven —
      see below), real Let's Encrypt TLS on a real domain, images pinned
      by digest (not `:latest`, not even a mutable tag)
- [x] **3 Advanced items, all proven working, not just present:**
      - **HPA** — proven scaling backend from 2→6 replicas under real
        memory pressure (`docs/EVIDENCE/hpa-scaling.txt`)
      - **PodDisruptionBudget + graceful shutdown** — `preStop` hooks on
        backend/frontend fixed a real ~2% request-drop bug during
        rollouts; re-tested afterward at 3332/3332 requests successful
        (`docs/EVIDENCE/zero-downtime-rollout.log`)
      - **NetworkPolicy** — genuinely enforced (k3s's bundled
        `kube-router` controller, not Calico — see ARCHITECTURE.md §4 for
        the full story of how this was discovered and two real policy
        bugs it surfaced and had fixed)
      - securityContext hardening also done on backend/frontend
        (Postgres deliberately exempted — documented trade-off, see
        ARCHITECTURE.md)
- [x] `docs/EVIDENCE/` filled: node/pod/TLS/ArgoCD screenshots, data
      persistence proof, zero-downtime rollout log, and a full live
      failover demo (hard-powered-off a worker node, 100/101 requests
      still succeeded, full recovery documented)
- [x] Live failover demo rehearsed and evidence captured
      (`docs/EVIDENCE/failover-demo-writeup.md`)

## What's genuinely still open (stretch-tier, not required for a strong grade)

- CI pipeline that auto-bumps image digests (Stretch goal, optional)
- Sealed Secrets so the Secret can live in git encrypted (Stretch, optional)
- Observability dashboard (kube-prometheus-stack) — metrics-server is
  already installed and `kubectl top` works; a Grafana dashboard on top
  would be a 4th Advanced item if you want extra distinction buffer, but
  3 solid Advanced items are already done

See `docs/ARCHITECTURE.md` for the "why" behind every design choice —
several sections document real bugs hit during the build (a Calico/GCP
networking incompatibility, a stale NetworkPolicy port reference, a
missing egress rule, an Argo CD sync-wave ordering bug) and how each was
diagnosed and fixed. That history is intentionally left in the docs: it's
the most concrete evidence that the infra actually works end-to-end, not
just that the YAML looks right.
