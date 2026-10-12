resource "kubectl_manifest" "monitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "cert-manager"
      namespace = var.namespace
    }

    spec = {
      endpoints = [{
        port = "http-metrics"
        path = "/metrics"
      }]

      selector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "cert-manager"
          "app.kubernetes.io/component" = "controller"
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
