resource "kubectl_manifest" "monitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "external-dns"
      namespace = var.namespace
    }

    spec = {
      endpoints = [{
        port = "http"
        path = "/metrics"
      }]

      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "external-dns"
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
