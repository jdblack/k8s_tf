resource kubectl_manifest monitor {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = var.name
      namespace = var.namespace
    }
    spec = {
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
        }
      ]

      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "seaweedfs"
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

