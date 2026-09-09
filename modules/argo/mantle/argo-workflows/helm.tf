# Install the argo-workflows chart.
#
# `version` is pinned on purpose: the chart defines the names of the
# ClusterRoles/Roles this module binds to (e.g. <release>-argo-workflows-admin)
# and the Service names the HTTPRoute targets (e.g.
# <release>-argo-workflows-server).  Bump deliberately, in its own change.
resource "helm_release" "workflows" {
  name            = var.name
  repository      = var.repo
  chart           = var.chart
  version         = var.chart_version
  namespace       = var.namespace
  upgrade_install = true
  wait            = true
  timeout         = 600

  values = [yamlencode(local.helm_values)]

  # Make sure the Authentik client secret exists before the chart's server
  # deployment starts (its sso config references it).
  depends_on = [kubernetes_secret_v1.oauth_secret]
}
