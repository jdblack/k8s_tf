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

# cert-manager-ingress only admits its own namespace and the nodes, so the scrape
# needs its own rule.
module "ingress_metrics" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "cert-manager-metrics-ingress"

  pod_selector = {
    "app.kubernetes.io/name"      = "cert-manager"
    "app.kubernetes.io/component" = "controller"
  }

  from_peers = [{
    namespace    = var.monitoring_namespace
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = [{ port = 9402 }]
  }]
}
