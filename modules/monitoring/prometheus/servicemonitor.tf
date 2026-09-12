# ntfy's /metrics.
#
# Created HERE rather than by the ntfy chart on purpose: the chart's own
# ServiceMonitor template is gated on
# `.Capabilities.APIVersions.Has "monitoring.coreos.com/v1"`, so on a
# from-scratch build (CRD absent while the ntfy release is templated) it is
# silently skipped -- and a steady-state helm no-op would never re-render it, so
# the metrics would simply never appear. This module installs that CRD, so it is
# always "after" it.
#
# Selects the Service by label, so it needs no reference to the ntfy module and
# creates no dependency edge (which is what keeps prometheus -> ntfy one-way).
resource "kubectl_manifest" "ntfy_servicemonitor" {
  count = var.ntfy == null ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "ntfy"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name" = "ntfy"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "ntfy"
        }
      }
      endpoints = [{
        port     = "metrics"
        path     = "/metrics"
        interval = "30s"
      }]
    }
  })

  # The CRD comes from this release.
  depends_on = [helm_release.prometheus]
}
