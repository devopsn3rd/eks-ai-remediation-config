#!/usr/bin/env bash
# Replaces ACCOUNT_ID and GUARDRAIL_ID placeholders in this repo. Run ONCE,
# after the foundation stack is applied, then commit and push.
# Usage: ./scripts/set-placeholders.sh <aws_account_id> <guardrail_id>
set -euo pipefail
ACCOUNT_ID="${1:?aws account id (12 digits)}"
GUARDRAIL_ID="${2:?guardrail id (terraform -chdir=foundation output -raw guardrail_id)}"

[[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || { echo "Account ID must be 12 digits" >&2; exit 1; }

cd "$(dirname "$0")/.."
files=$(grep -rlE 'ACCOUNT_ID|GUARDRAIL_ID' --include='*.yaml' . || true)
for f in $files; do
  # macOS (BSD) and Linux (GNU) sed both accept -i.bak
  sed -i.bak -e "s/ACCOUNT_ID/${ACCOUNT_ID}/g" -e "s/GUARDRAIL_ID/${GUARDRAIL_ID}/g" "$f"
  rm -f "$f.bak"
  echo "updated $f"
done
echo "Done. Review with: git diff"
