# Install the argo-workflows chart.
#
# `version` is pinned on purpose: the chart defines the names of the
# ClusterRoles/Roles this module binds to (e.g. <release>-argo-workflows-admin) and
# the Service names the HTTPRoute targets (e.g. <release>-argo-workflows-server).
# Bump deliberately, in its own change.
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

  # The chart's server deployment references this secret in its sso config, so it
  # must exist first.
  depends_on = [kubernetes_secret_v1.oauth_secret]
}
