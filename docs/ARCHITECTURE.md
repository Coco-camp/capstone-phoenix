# Architecture — Phoenix

## 1. Node topology

```
                                Internet
                                   │
                        ┌──────────┴──────────┐
                        │   ports 80/443 only  │
                        │  (Hetzner firewall)  │
                        └──────────┬──────────┘
                                   │
                     ┌─────────────┴─────────────┐
                     │      cp-1 (control-plane)  │
                     │  k3s server + Traefik       │
                     │  + cert-manager + Argo CD   │
                     │  10.10.1.10 (private)       │
                     └─────────────┬─────────────┘
                     private network 10.10.0.0/16
              ┌────────────────────┼────────────────────┐
              │                                          │
   ┌──────────┴──────────┐                   ┌───────────┴──────────┐
   │  worker-1            │                   │  worker-2             │
   │  10.10.1.10+1         │                   │  10.10.1.10+2          │
   │  frontend, backend    │                   │  frontend, backend     │
   │  replicas (spread)    │                   │  replicas (spread)     │
   │  postgres (pinned)    │                   │                        │
   └───────────────────────┘                   └────────────────────────┘
```

3 nodes: 1 control-plane (k3s server, also runs Traefik ingress + cert-manager
+ Argo CD — all control-plane/platform tooling, not app workloads) and 2
workers, which is where `frontend`, `backend`, and `postgres` actually run.
All three sit on a private GCP VPC subnet (`10.10.1.0/24`); only 22/80/443
are reachable from the public internet (see `infra/terraform/modules/firewall`).
Provisioned on GCP (not the originally-planned Hetzner) specifically because
the `taskapp-backend`/`taskapp-frontend` images are amd64-only — GCP's free
trial credit runs amd64-native instances at $0 out-of-pocket cost for the
capstone window, vs. a free ARM tier that would have required rebuilding
both images. See `docs/COST.md` for the full trade-off.

## 2. Request flow

```
Browser
  → DNS: taskapp.<domain> → cp-1 public IP
  → Hetzner firewall (443 open)
  → Traefik (Ingress controller, runs as a DaemonSet-ish workload, TLS
    terminated here using the taskapp-tls Secret cert-manager issued)
  → path /            → frontend Service → frontend Pod (nginx, static build)
  → path /api/*       → backend Service  → backend Pod (Flask)
  → backend           → postgres Service (headless, ClusterIP: None)
                       → postgres-0 Pod (StatefulSet, PVC pinned to one node)
```

Same-origin routing (`taskapp.<domain>/api`) was chosen over a separate
`api.<domain>` subdomain so the React app's existing relative `/api` calls
need no CORS configuration and there's one cert/Ingress object instead of two.

## 3. What each Core requirement fixes vs. the single-server (Portainer) setup

| Requirement | Single-server assumption it breaks |
|---|---|
| Namespace + ConfigMap/Secret split | Portainer's `.env` per-stack assumed one host; a namespace is the multi-tenant unit K8s actually schedules against |
| Postgres StatefulSet + PVC | Docker volume was pinned to the one host by definition; a PVC + storage class makes "which node has the data" an explicit, provable binding instead of an accident |
| 2+ replicas, topology spread | One container = one point of failure. Spread constraints stop both replicas from landing on the same node, which would silently recreate the single-server failure mode inside a "multi-node" cluster |
| Migration Job, not entrypoint | Fine at 1 replica; at 2+ replicas booting concurrently, in-entrypoint migrations race on `alembic upgrade head` — a Job runs it exactly once, before the replicas start |
| Liveness/readiness/startup probes | Docker's restart-on-crash has no concept of "unhealthy but still running" (e.g. DB pool exhausted); probes let K8s pull a pod from the Service without killing it |
| Requests/limits | No scheduler existed before — K8s needs requests to bin-pack pods across 3 nodes sanely, and limits to stop one runaway container starving its node-mates |
| RollingUpdate maxUnavailable:0 | Portainer redeploy = brief downtime by design; this guarantees old replicas don't terminate until new ones pass readiness |
| Ingress + cert-manager TLS | Previously one nginx container held the cert file; now cert-manager auto-renews and re-issues without touching a filesystem by hand |
| Pinned tags | `:latest` on one server was "whatever I last pushed" — meaningless (and dangerous) once GitOps + multiple replicas can pull the tag independently at different times |

## 4. NetworkPolicy model

Default-deny in `taskapp` namespace, then explicit allows:
`frontend/backend` ← Traefik (kube-system) · `backend` ← `frontend` + the
migration Job · `postgres` ← `backend` + the migration Job only. k3s's default
CNI (Flannel) does not enforce `NetworkPolicy` — see `docs/RUNBOOK.md` for the
Calico swap that makes these policies real rather than decorative YAML.

## 5. Trade-offs (worth stating up front)

- **Single control-plane, no HA etcd.** README explicitly scopes this out —
  the assignment is about Kubernetes itself, not etcd quorum.
- **Postgres is a single replica pinned to whichever node its PVC first
  binds to** (k3s's default `local-path` storage class is node-local, not
  networked -- true on GCP just as it was on the originally-planned Hetzner
  setup). A real HA Postgres (Patroni, or a managed DB like Cloud SQL) is
  listed as a Stretch item precisely because it's a genuinely different,
  harder problem.
- **Secrets are applied manually**, not through GitOps, until Sealed Secrets
  (Stretch) is done — see `manifests/base/secret.example.yaml`.
- **Postgres does not run the full securityContext hardening** applied to
  backend/frontend (no forced `runAsNonRoot`/`runAsUser`, no capability
  drop). The official `postgres:16-alpine` image's own entrypoint needs
  brief root access to `chown`/`chmod` its data dir and unix socket before
  it demotes itself internally — forcing non-root at the pod level broke
  this with `chmod: /var/run/postgresql: Operation not permitted` and
  startup-probe failures, confirmed during first deploy. This is the same
  trust boundary the image has under plain Docker; backend/frontend (images
  we control) keep full hardening since we know they don't need root at all.
