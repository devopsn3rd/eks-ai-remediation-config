#!/usr/bin/env bash
# One-time bootstrap: install Argo CD, then hand control to Git.
# Run from your laptop AFTER the terraform-apply workflow finished and
# AFTER the first app CI run pushed images (guide 6.4).
#
#   export AWS_PROFILE=terraform-deployer
#   ./bootstrap/bootstrap.sh
set -euo pipefail

CLUSTER="${CLUSTER:-eks-ai-remediation}"
REGION="${REGION:-us-east-1}"
ARGOCD_CHART_VERSION="10.15.0" # keep equal to apps/argocd.yaml targetRevision

cd "$(dirname "$0")/.."

echo "==> Pre-flight checks"
for bin in aws kubectl helm; do
  command -v "$bin" >/dev/null || { echo "Missing tool: $bin" >&2; exit 1; }
done
if grep -rqE 'ACCOUNT_ID|GUARDRAIL_ID' --include='*.yaml' apps envs workloads platform agents; then
  echo "Placeholders still present. Run scripts/set-placeholders.sh first (guide 6.2)." >&2
  exit 1
fi

echo "==> kubeconfig for ${CLUSTER}"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl get nodes -o wide

echo "==> Installing Argo CD (chart ${ARGOCD_CHART_VERSION}) — the only manual helm install"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  -f platform/argocd/values.yaml \
  --wait --timeout 10m

echo "==> Handing control to Git: root Application (app of apps)"
kubectl apply -f bootstrap/root-app.yaml

cat <<MSG

Argo CD is installed and now manages itself and everything in apps/.

Admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
Argo CD UI (user: admin):
  kubectl -n argocd port-forward svc/argocd-server 8081:80   ->  http://localhost:8081
Watch the sync waves:
  kubectl -n argocd get applications -w
MSG
