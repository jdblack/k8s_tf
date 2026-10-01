#!/bin/sh
# Publishes the pinned oCIS chart to GitHub Container Registry.
#
# ownCloud stopped publishing this chart, so there is no upstream repository to install
# from. This repo publishes it once instead, from the commit that pins it, and the module
# installs what lands here -- the commit below is the provenance of the artifact.
#
# Needs a token carrying write:packages: run `helm registry login ghcr.io -u <user>` first.
set -eu

REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-jdblack/ocis-charts}"

CHART_COMMIT="${CHART_COMMIT:-fdd5f39b26fe0e7dfeec5697098be226de0eadbd}"
CHART_VERSION="${CHART_VERSION:-0.8.0}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "https://codeload.github.com/owncloud/ocis-charts/tar.gz/$CHART_COMMIT" -o "$work/src.tgz"

# Stripped so the path does not depend on how codeload spells the ref.
mkdir -p "$work/src"
tar -xzf "$work/src.tgz" -C "$work/src" --strip-components=1

# The pinned commit and the version about to be tagged have to agree, or the registry ends
# up serving a version that is not what it claims.
staged=$(sed -n 's/^version:[[:space:]]*//p' "$work/src/charts/ocis/Chart.yaml")
if [ "$staged" != "$CHART_VERSION" ]; then
  echo "chart at $CHART_COMMIT is version $staged, expected $CHART_VERSION" >&2
  exit 1
fi

helm package "$work/src/charts/ocis" -d "$work"
helm push "$work/ocis-$CHART_VERSION.tgz" "oci://$REGISTRY/$NAMESPACE"

echo "published oci://$REGISTRY/$NAMESPACE/ocis:$CHART_VERSION from $CHART_COMMIT"
