#!/bin/sh
# Converges the SeaweedFS backup target; every step is create-or-update, so re-runs are no-ops.
set -eu

ws() {
  printf '%s\n' "$1" | kubectl -n "$SEAWEEDFS_NAMESPACE" exec -i "deploy/$SEAWEEDFS_RELEASE" \
    -c "$SEAWEEDFS_CONTAINER" -- weed shell -master="$SEAWEEDFS_MASTER"
}

ws "s3.bucket.create -name $BUCKET"
ws "s3.user.provision -name $USER -bucket $BUCKET -role $ROLE"

# provision mints its own key; keep only the pair Terraform generated.
if ! ws "s3.user.show -name $USER" | grep -q "\"access_key\":\"$ACCESS_KEY\""; then
  ws "s3.accesskey.create -user $USER -access_key $ACCESS_KEY -secret_key $SECRET_KEY"
fi

for key in $(ws "s3.user.show -name $USER" | grep -o '"access_key":"[^"]*"' | cut -d'"' -f4); do
  [ "$key" = "$ACCESS_KEY" ] || ws "s3.accesskey.delete -user $USER -access_key $key"
done
