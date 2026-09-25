resource "kubectl_manifest" "monitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "velero"
      namespace = var.namespace
    }

    spec = {
      endpoints = [{
        port = "http-monitoring"
        path = "/metrics"
      }]

      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "velero"
        }
      }

      namespaceSelector = {
        matchNames = [
          var.namespace
        ]
      }
    }
  })
}
