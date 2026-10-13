# The chart renders the whole workload -- runner Deployment with its DinD sidecar, the
# registration pre-install Job, the ServiceAccount and the config Secrets. See locals.tf.
#
# This is OUR OWN copy of the chart, not a public one: `support/forgejo-chart-vendor` mirrors the
# upstream (code.forgejo.org/forgejo-helm/forgejo-runner, which publishes no OCI artifact) into the
# Forgejo org `forgejo`, then `helm package`s and pushes it to Harbor. The instance+version consumed
# here are `var.chart_repository` / `var.chart_version`; re-run that script, bump the version.
resource "helm_release" "runner" {
  name       = var.name
  namespace  = kubernetes_namespace_v1.namespace.metadata[0].name
  repository = var.chart_repository
  chart      = var.chart
  version    = var.chart_version

  wait    = true
  timeout = 600

  values = [yamlencode(local.helm_values)]

  # The pre-install register Job reads the token from this Secret, so it has to exist first.
  depends_on = [kubernetes_secret_v1.registration]
}
