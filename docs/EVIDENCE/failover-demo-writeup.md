Proof: live failover - worker node power-off
================================================

Setup: continuous HTTP check against https://collins-phoenix.duckdns.org
every 2 seconds, running in the background, while phoenix-worker-1 (which
was running 1 backend + 1 frontend replica at the time) was hard powered
off via `sudo poweroff` over SSH -- not a graceful `kubectl drain`, a real
simulated node failure.

Timeline:
1. Background monitor started: `while true; do date; curl -s -o /dev/null
   -w "%{http_code}\n" https://collins-phoenix.duckdns.org; sleep 2; done`
2. `ssh deploy@<worker-1-ip> "sudo poweroff"` -- node goes dark immediately
3. ~40s later: `kubectl get nodes` shows phoenix-worker-1 as NotReady
4. Kubernetes' default eviction grace period (~5 min) elapses, then pods
   that were on worker-1 are evicted and rescheduled onto the two
   surviving nodes (phoenix-cp-1, phoenix-worker-2)
5. Worker-1 restarted via GCP Console; rejoined the cluster automatically
   (k3s-agent is a systemd service, starts on boot)
6. Final state: all 3 nodes Ready again, pods redistributed back across
   all 3 nodes

Result (see failover-test.log for full raw output):
- 101 total HTTP checks across the whole event
- 100 returned 200
- 1 returned 504 -- occurring in the exact 2-second window right as the
  node went dark, before Traefik/kube-proxy had removed the now-dead pod
  from the Service's routing table
- Site was back to 100% 200s within one check interval (2 seconds) and
  stayed there through the rest of the outage and recovery

This is expected, realistic behavior for a hard (non-graceful) node
failure: a single in-flight request can land on a pod in the instant
before Kubernetes' health-check/endpoint-removal machinery reacts. This
is meaningfully different from (and a harder test than) a `kubectl drain`,
which lets pods finish in-flight work and lets the Service properly
de-register endpoints before anything actually stops -- graceful drains
in this cluster show zero dropped requests (see zero-downtime-rollout.log
for the equivalent evidence during a planned rolling update, which uses
the same preStop-hook-based graceful shutdown path).
