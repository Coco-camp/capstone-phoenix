# Runbook — Phoenix

Every command below assumes you're at the repo root unless a `cd` says
otherwise. Written for WSL/Ubuntu (Terraform + Ansible run there, not
native Windows).

## 0. One-time prerequisites

```bash
sudo apt update
sudo apt install -y ansible git unzip docker.io   # terraform installed separately, see below

# Terraform (if not already installed):
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# SSH key, if you don't already have one
ssh-keygen -t ed25519 -C "you@laptop"

# GCP
#  - console.cloud.google.com -> create project "capstone-phoenix"
#  - link billing (free trial credit)
#  - enable the Compute Engine API
#  - IAM & Admin > Service Accounts > create "terraform-admin", role: Editor
#  - that service account > Keys > Add Key > JSON -> downloads a key file
mkdir -p ~/.gcp
mv ~/Downloads/capstone-phoenix-*.json ~/.gcp/terraform-key.json   # adjust path if not using WSL/Windows
chmod 600 ~/.gcp/terraform-key.json

# Terraform Cloud (remote state)
terraform login   # opens a browser, generates ~/.terraform.d/credentials.tfrc.json
```

## 1. Provision infrastructure (Terraform)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars:
#   gcp_project_id       = your actual project ID
#   gcp_credentials_file = "~/.gcp/terraform-key.json"
#   admin_ip_cidr         = "$(curl -s ifconfig.me)/32"
#   ssh_public_key         = contents of ~/.ssh/id_ed25519.pub

terraform init
terraform plan
terraform apply    # ~60-90 seconds, creates 3 VM instances + VPC + firewall rules
```

This also writes `infra/ansible/inventory/hosts.ini` automatically.

## 2. Bring up the cluster (Ansible)

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml

# wait ~30s after terraform apply for the VMs' SSH daemon + metadata-based
# user creation to finish, then:
ansible-playbook playbook.yml
```

Acceptance check (from your laptop/WSL):

```bash
export KUBECONFIG=$(pwd)/../../kubeconfig
kubectl get nodes -o wide
# expect: 1 control-plane + 2 workers, all Ready
```

> **Why you can't just hit :6443 directly:** the GCP firewall intentionally
> scopes 6443/8472/10250 to the VPC's own subnet only (see the firewall
> module's `internal` rule) -- never the public internet. For ad-hoc access
> beyond the generated kubeconfig, tunnel instead:
> `ssh -L 6443:127.0.0.1:6443 deploy@<control-plane-ip>` then point
> `KUBECONFIG`'s server at `https://127.0.0.1:6443`.

## 3. CNI: plain Flannel (Calico attempted, reverted -- see ARCHITECTURE.md)

k3s's default CNI (Flannel) doesn't enforce `NetworkPolicy`. Calico was
tried as a policy-enforcing replacement during this build, but hit a
persistent GCP-specific networking bug (Calico's VXLAN/IPIP tunnel
interfaces retained stale IPAM state across multiple clean k3s
reinstalls, breaking cross-node Service routing for gRPC-heavy traffic
like Argo CD's own internal components) that wasn't resolved within a
reasonable time budget. Decision: stay on plain Flannel, keep the
`NetworkPolicy` manifests in the repo as documentation of intent (see
`manifests/base/networkpolicy/`), and note honestly in `docs/ARCHITECTURE.md`
that they are not currently enforced. This trades one Advanced-category
checkbox for actually shipping the Core app and GitOps on schedule.

## 4. Install platform tooling

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

kubectl create namespace argocd
helm install argocd argo/argo-cd --namespace argocd

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 5. First-time secret (manual, not GitOps -- see secret.example.yaml)

```bash
cp manifests/base/secret.example.yaml /tmp/secret.yaml
# edit /tmp/secret.yaml with real values
kubectl apply -f /tmp/secret.yaml
rm /tmp/secret.yaml
```

## 6. Point the manifests at your real image tags and domain

Images are pinned by digest (not a mutable tag) in
`manifests/overlays/prod/kustomization.yaml` — get the current digest for
any image with:

```bash
docker manifest inspect ghcr.io/ts-a-devops/taskapp-backend:latest
# copy the amd64 entry's "digest" field (ignore any "unknown/unknown" attestation entry)
```

Then edit `manifests/overlays/prod/kustomization.yaml` directly (digests
don't lend themselves to a one-line `sed` the way a placeholder string does):

```yaml
images:
  - name: ghcr.io/ts-a-devops/taskapp-backend
    digest: sha256:<paste digest here>
  - name: ghcr.io/ts-a-devops/taskapp-frontend
    digest: sha256:<paste digest here>
```

```bash
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
kubectl get applications -n argocd
```

From this point on: never `kubectl apply` the app manually again. Change
`manifests/overlays/prod/`, commit, push -- Argo CD reconciles automatically.

## 8. Prove it (fill docs/EVIDENCE/)

```bash
kubectl get nodes -o wide
kubectl get pods -n taskapp -o wide
curl -vI https://taskapp.<yourdomain> 2>&1 | grep -E "subject|issuer"

kubectl exec -n taskapp postgres-0 -- psql -U taskapp -c "INSERT INTO ..."
kubectl delete pod -n taskapp postgres-0
kubectl exec -n taskapp postgres-0 -- psql -U taskapp -c "SELECT ..."

hey -z 60s -c 10 https://taskapp.<yourdomain>/api/health &
kubectl set image deployment/backend backend=ghcr.io/.../taskapp-backend:<new-sha> -n taskapp

hey -z 120s -c 50 https://taskapp.<yourdomain>/api/health &
kubectl get hpa -n taskapp -w
```

## 9. Failure recovery drills (for the viva)

**Dead worker:**
```bash
gcloud compute instances stop phoenix-worker-2 --zone=us-central1-a
kubectl get nodes -w
kubectl get pods -n taskapp -o wide -w
```

**Dead backend pod:**
```bash
kubectl delete pod -n taskapp -l app=backend --field-selector status.phase=Running --now
```

**Bad migration:**
```bash
git revert <bad-commit> && git push
```

## 10. Tear down (to stop burning free-trial credit)

```bash
kubectl delete -f gitops/application.yaml
cd infra/terraform && terraform destroy
```
