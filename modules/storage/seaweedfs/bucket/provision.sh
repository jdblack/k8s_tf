#!/bin/sh
# Converges one SeaweedFS bucket; every step is create-or-update, so re-runs are no-ops.
set -eu

ws() {
  printf '%s\n' "$1" | kubectl -n "$SEAWEEDFS_NAMESPACE" exec -i "deploy/$SEAWEEDFS_RELEASE" \
    -c "$SEAWEEDFS_CONTAINER" -- weed shell -master="$SEAWEEDFS_MASTER"
}

ws "s3.bucket.create -name $BUCKET"

# create rewrites the bucket entry, which drops any owner, so it has to be set afterwards.
if [ -n "$OWNER" ]; then
  ws "s3.bucket.owner -name $BUCKET -owner $OWNER"
fi
