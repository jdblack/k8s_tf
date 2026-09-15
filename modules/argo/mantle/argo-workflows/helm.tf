# Install the argo-workflows chart.
#
# `version` is pinned on purpose: the chart defines the names this module binds to (the
# <release>-argo-workflows-admin ClusterRole, the server Service the HTTPRoute targets), so
# bump deliberately, in its own change.
resource "helm_release" "workflows" {
  name            = var.name
  repository      = var.repo
  chart           = var.chart
  version         = var.helm_version
  namespace       = var.namespace
  upgrade_install = true
  wait            = true
  timeout         = 600

  values = [yamlencode(local.helm_values)]

  # The chart's server deployment references this secret, so it must exist first.
  depends_on = [kubernetes_secret_v1.oauth_secret]
}
