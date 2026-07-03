# Runbook — Phoenix

Every command below assumes you're at the repo root unless a `cd` says
otherwise.

## 0. One-time prerequisites

```bash
# Tools
brew install terraform ansible kubectl kustomize hcloud helm   # macOS
# or: your distro's package manager equivalents

# Hetzner
#  - create account at https://console.hetzner.cloud
#  - Security > API Tokens > generate a Read+Write token
export TF_VAR_hcloud_token="paste-token-here"

# Terraform Cloud (remote state)
terraform login   # opens a browser, generates ~/.terraform.d/credentials.tfrc.json

# SSH key, if you don't already have one
ssh-keygen -t ed25519 -C "you@laptop" -f ~/.ssh/id_ed25519
```

## 1. Provision infrastructure (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set admin_ip_cidr to "$(curl -s ifconfig.me)/32"
# and ssh_public_key to the contents of ~/.ssh/id_ed25519.pub

terraform init
terraform plan
terraform apply    # ~90 seconds, creates 3 servers + network + firewall
```

This also writes `infra/ansible/inventory/hosts.ini` automatically — no
manual IP copy/paste.

## 2. Bring up the cluster (Ansible)

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml

# wait ~30s after terraform apply for cloud-init/sshd to be ready, then:
ansible-playbook playbook.yml
```

Acceptance check (from your laptop):

```bash
export KUBECONFIG=$(pwd)/../../kubeconfig
kubectl get nodes -o wide
# expect: 1 control-plane + 2 workers, all Ready
```

> **Why you can't just hit :6443 directly:** the Hetzner firewall
> intentionally does not expose 6443 to the internet (see
> `docs/ARCHITECTURE.md` §4 / the firewall module comments). For ad-hoc
> access beyond the generated kubeconfig, tunnel instead:
> `ssh -L 6443:127.0.0.1:6443 deploy@<control-plane-ip>` then point
> `KUBECONFIG`'s server at `https://127.0.0.1:6443`.

## 3. Swap Flannel for a policy-enforcing CNI (Calico)

k3s's default CNI doesn't enforce `NetworkPolicy`. Two options — pick one and
note your choice in `docs/ARCHITECTURE.md`:

- **Simplest:** re-run the k3s install with `--flannel-backend=none`
  (edit `infra/ansible/roles/k3s_server/tasks/main.yml`), then:
  ```bash
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
  ```
- **Or:** keep Flannel and layer Calico in policy-only mode
  (`calico.yaml` with `CALICO_NETWORKING_BACKEND=none`) — enforces policy
  without replacing the CNI you already validated in step 2.

## 4. Install platform tooling

```bash
# Traefik ships with k3s already. Add cert-manager + Argo CD + metrics-server:

helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd

kubectl apply -f https://github.com/k3s-io/k3s/raw/master/manifests/metrics-server.yaml
```

## 5. First-time secret (manual, not GitOps — see secret.example.yaml)

```bash
cp manifests/base/secret.example.yaml /tmp/secret.yaml
# edit /tmp/secret.yaml with real values
kubectl apply -f /tmp/secret.yaml
rm /tmp/secret.yaml
```

## 6. Point the manifests at your real image tags and domain

```bash
# get the commit SHA of the image you built in the Docker lesson
export SHA=$(git ls-remote https://github.com/ts-a-devops/taskapp-backend main | cut -c1-7)

sed -i "s/CHANGE_ME_PINNED_SHA/${SHA}/g" manifests/overlays/prod/kustomization.yaml
sed -i "s/CHANGE_ME.taskapp.example.com/taskapp.<yourdomain>/g" manifests/base/ingress.yaml
sed -i "s/CHANGE_ME@example.com/you@yourdomain/g" manifests/base/cluster-issuer.yaml
sed -i "s#CHANGE_ME/capstone-phoenix#<your-github-username>/capstone-phoenix#" gitops/application.yaml

git add -A && git commit -m "Set real image tags, domain, repo URL" && git push
```

Point your domain's DNS `A` record at the control-plane's public IP
(`terraform output control_plane_public_ip`).

## 7. Let GitOps take over

```bash
kubectl apply -f gitops/application.yaml
kubectl get applications -n argocd    # watch it go Synced + Healthy
```

From this point on: **never `kubectl apply` the app manually again.** Change
`manifests/overlays/prod/`, commit, push — Argo CD reconciles within ~3
minutes (or force it: `argocd app sync taskapp`).

## 8. Prove it (fill docs/EVIDENCE/)

```bash
# nodes ready
kubectl get nodes -o wide

# pods spread across nodes
kubectl get pods -n taskapp -o wide

# TLS is real
curl -vI https://taskapp.<yourdomain> 2>&1 | grep -E "subject|issuer"

# data survives a pod kill
kubectl exec -n taskapp postgres-0 -- psql -U taskapp -c "INSERT INTO ..."
kubectl delete pod -n taskapp postgres-0
kubectl exec -n taskapp postgres-0 -- psql -U taskapp -c "SELECT ..."  # still there

# zero-downtime rollout (needs `hey` or similar installed locally)
hey -z 60s -c 10 https://taskapp.<yourdomain>/api/health &
kubectl set image deployment/backend backend=ghcr.io/.../taskapp-backend:<new-sha> -n taskapp
# check hey's output after: 0 non-200s

# HPA scaling under load
hey -z 120s -c 50 https://taskapp.<yourdomain>/api/health &
kubectl get hpa -n taskapp -w
```

## 9. Failure recovery drills (for the viva)

**Dead worker:**
```bash
# power off worker-2 from the Hetzner console (or hcloud CLI), then:
kubectl get nodes -w         # NotReady after ~40s
kubectl get pods -n taskapp -o wide -w   # pods reschedule to worker-1
```

**Dead backend pod:**
```bash
kubectl delete pod -n taskapp -l app=backend --field-selector status.phase=Running -l app=backend --now
# readiness probe + Service endpoints mean the surviving replica keeps serving
```

**Bad migration:**
```bash
# Job's backoffLimit: 3 means it retries then fails visibly instead of
# silently corrupting state; roll back by reverting the git commit that
# bumped the image tag — Argo CD's PreSync hook re-runs migrate against the
# previously-good image on the next sync.
git revert <bad-commit> && git push
```

## 10. Tear down (to stop paying for it)

```bash
kubectl delete -f gitops/application.yaml   # let Argo CD clean up first
cd infra/terraform && terraform destroy
```
