#!/bin/sh
# make-resident-secret.sh — mint the resident-cline Secret in cline-home.
#
# RUN THIS YOURSELF. It reads your DeepSeek key from the local Cline secrets and writes it into the
# cluster; it never prints the value. It is the one HUMAN-GATED step of the resident Cline: a
# credential belongs to its owner, so an agent should not copy it on your behalf.
#
# After this, set `enable_resident = true` in the cline-home stack and apply.
set -eu

SECRETS="${CLINE_SECRETS:-$HOME/.cline/data/secrets.json}"
NS="${CLINE_HOME_NS:-cline-home}"

KEY=$(jq -r '.deepSeekApiKey' "$SECRETS")
[ -n "$KEY" ] && [ "$KEY" != "null" ] || { echo "no deepSeekApiKey in $SECRETS" >&2; exit 1; }

# --from-literal briefly puts the value in argv; acceptable for a local one-shot. Prefer --from-file
# if you care about that.
kubectl -n "$NS" create secret generic resident-cline \
  --from-literal=deepSeekApiKey="$KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "resident-cline Secret applied in $NS (value not printed)."
echo "Next: set enable_resident = true in stacks/cline-home and apply."
