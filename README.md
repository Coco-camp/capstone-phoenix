# Phoenix — TaskApp on real Kubernetes

Capstone submission for `ts-a-devops/capstone-phoenix`. TaskApp
(React/nginx + Flask/Postgres) running highly-available, autoscaling,
zero-downtime, on a 3-node k3s cluster on Google Cloud Platform, behind
HTTPS, entirely GitOps-owned via Argo CD. (Originally scoped for Hetzner;
switched to GCP since the published app images are amd64-only and GCP's
free trial credit covers the full capstone window at $0 — see
`docs/COST.md`.)

## Layout

```
infra/terraform/   3-node GCP cluster: network, firewall, compute
infra/ansible/     k3s bring-up: hardening, k3s server, k3s agent roles
manifests/base/    all K8s resources (kustomize base)
manifests/overlays/prod/   pinned image tags — the only file CI/you edit to ship
gitops/            the one Argo CD Application you kubectl apply, once
docs/              ARCHITECTURE.md, RUNBOOK.md, COST.md, EVIDENCE/
```

## Start here

**`docs/RUNBOOK.md`** — every command, in order, from zero to a live,
GitOps-managed cluster.

## Status

- [ ] `terraform apply` — 3 nodes up, remote state, least-priv firewall
- [ ] `ansible-playbook playbook.yml` — `kubectl get nodes` all Ready
- [ ] Calico installed — NetworkPolicy actually enforced
- [ ] cert-manager + Argo CD + metrics-server installed
- [ ] Secret applied manually
- [ ] Real image tags + domain substituted, pushed
- [ ] `gitops/application.yaml` applied — Argo CD Synced + Healthy
- [ ] Core §4 checklist (README) — all boxes demonstrated
- [ ] ≥3 Advanced items — HPA + PDB/securityContext done and working;
      NetworkPolicy manifests written but not enforced (Flannel doesn't
      enforce them; Calico attempted, hit a GCP-specific bug, reverted —
      see ARCHITECTURE.md §4). Need a 3rd real Advanced item.
      (observability dashboard is the natural next one — see below)
- [ ] `docs/EVIDENCE/` filled with screenshots
- [ ] Live failover demo rehearsed

## What's scaffolded vs. what's still yours to do

**Scaffolded (this commit):** all Terraform/Ansible/manifests described
above, Core §4 fully covered, 2 solid Advanced items working (HPA, PDB +
securityContext hardening on backend/frontend). NetworkPolicy manifests
exist but aren't enforced (documented trade-off — see ARCHITECTURE.md),
GitOps wiring in place.

**Still needed from you:**
1. A domain (any registrar) pointed at the control-plane IP.
2. Your actual `taskapp-backend` / `taskapp-frontend` image SHAs.
3. Run through `docs/RUNBOOK.md` end to end — some values are `CHANGE_ME`
   placeholders by design, so this **will not** apply cleanly until you do.
4. Pick + implement a real 3rd Advanced item — observability
   (kube-prometheus-stack) is the natural pick since metrics-server is
   already installed in the runbook.
5. `docs/EVIDENCE/` screenshots and the live demo.

See `docs/ARCHITECTURE.md` for the "why" behind every design choice, and
each file's own comments for the "why" at that specific decision point.
