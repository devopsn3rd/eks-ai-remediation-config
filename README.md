# eks-ai-remediation-config

The desired state of the cluster. Argo CD syncs everything here.

```
bootstrap/   bootstrap.sh (one-time Argo CD install), root-app.yaml, teardown.sh
apps/        one Argo CD Application per component (app of apps), sync waves -3..3
platform/    values for Argo CD (self-managed) and kagent; default gp3 StorageClass
agents/      the orders-sre Agent, its ServiceAccount, and the MCP server registration
workloads/   orders-runbook-mcp and alert-bridge manifests
charts/      orders-api Helm chart
envs/lab/    orders-api values — CI bumps the image tag; the agent proposes fixes via PR
```

Lines ending in `# agent:...` or `# ci:image` are edited by machines. Keep the markers.
