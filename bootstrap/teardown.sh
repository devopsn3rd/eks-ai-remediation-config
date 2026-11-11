#!/usr/bin/env bash
# Controlled teardown BEFORE terraform destroy.
# Deletes the Argo CD apps so Kubernetes-created AWS resources (the EBS volume
# behind kagent's PostgreSQL, any load balancer) are removed while the cluster
# still exists. Then (optionally) starts the terraform-destroy workflow.
#
#   export AWS_PROFILE=terraform-deployer
#   ./bootstrap/teardown.sh            # cleanup only
#   ./bootstrap/teardown.sh --destroy  # cleanup + start the destroy workflow (needs gh)
set -euo pipefail

INFRA_REPO="${INFRA_REPO:-devopsn3rd/eks-ai-remediation-infra}"

echo "==> 1/4 Remove the root app (children keep running, but nothing recreates them)"
kubectl -n argocd delete application root --ignore-not-found --wait=true

echo "==> 2/4 Delete workload apps (cascade: their finalizers delete the resources)"
for app in alert-bridge agents orders-runbook-mcp orders-api kagent kagent-crds platform-storage; do
  kubectl -n argocd delete application "$app" --ignore-not-found --wait=false
done

echo "==> 3/4 Waiting for PersistentVolumes and LoadBalancer Services to disappear"
for i in $(seq 1 60); do
  pvs=$(kubectl get pv --no-headers 2>/dev/null | wc -l | tr -d ' ')
  lbs=$(kubectl get svc -A --no-headers 2>/dev/null | awk '$3=="LoadBalancer"' | wc -l | tr -d ' ')
  apps=$(kubectl -n argocd get applications --no-headers 2>/dev/null | grep -vc '^argocd ' || true)
  echo "   PVs=${pvs} LoadBalancers=${lbs} apps-left=${apps}"
  if [ "$pvs" = "0" ] && [ "$lbs" = "0" ] && [ "$apps" = "0" ]; then break; fi
  sleep 10
done

echo "==> 4/4 Cluster is clean of AWS-backed Kubernetes resources."
if [ "${1:-}" = "--destroy" ]; then
  command -v gh >/dev/null || { echo "gh CLI not found; run the workflow from the GitHub UI." >&2; exit 1; }
  gh workflow run terraform-destroy.yml -R "$INFRA_REPO" -f confirm=destroy
  echo "terraform-destroy started. Approve it in GitHub: Actions -> terraform-destroy -> Review deployments."
else
  echo "Next: GitHub -> ${INFRA_REPO} -> Actions -> terraform-destroy -> Run workflow (type: destroy)."
fi
