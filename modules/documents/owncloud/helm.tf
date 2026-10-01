# Published to GitHub Container Registry by publish_chart.sh, from the commit recorded in
# that script: ownCloud stopped publishing this chart (owncloud.github.io/ocis-charts 301s
# to owncloud.dev, which 404s, and the repo has no gh-pages branch, no OCI artifact and no
# release asset), so there is no upstream repository to install from.
#
# 900s rather than the usual 600: this is one release of thirty-odd services, and the three
# holding ReadWriteOnce claims roll one replica at a time.
resource "helm_release" "ocis" {
  name      = var.name
  namespace = var.namespace

  repository = var.chart_registry
  chart      = "ocis"
  version    = var.helm_version

  wait    = true
  timeout = 900

  values = [yamlencode(local.helm_values)]

  # The release mounts the claims and reads the credentials at first start, so none of
  # them can be created by it.
  depends_on = [
    module.bucket,
    module.s3_user,
    module.oidc,
    kubernetes_secret_v1.ldap,
    kubernetes_persistent_volume_claim_v1.metadata,
    kubernetes_persistent_volume_claim_v1.storagesystem,
    kubernetes_persistent_volume_claim_v1.nats,
  ]
}

