module "ingress_metrics" {
  source = "../network/firewalls/ingress"

  namespace    = kubernetes_namespace_v1.this.metadata[0].name
  name         = "documents-metrics-ingress"
  pod_selector = local.labels

  from_peers = [{
    namespace    = var.monitoring_namespace
    pod_selector = { "app.kubernetes.io/name" = "prometheus" }
    ports        = [{ port = local.flower_port }]
  }]
}

# Flower is the only metrics surface here: paperless itself exposes no /metrics.
resource "kubectl_manifest" "monitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = var.name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }

    spec = {
      endpoints = [{
        port = "flower"
        path = "/metrics"
      }]

      selector = {
        matchLabels = local.labels
      }

      namespaceSelector = {
        matchNames = [var.namespace]
      }
    }
  })
}

locals {
  # No blackbox exporter in this cluster, so absence of a replica is read from kube-state-metrics.
  app_alerts = [
    {
      alert = "DocumentsAppUnavailable"
      expr  = "kube_deployment_status_replicas_available{namespace=\"${var.namespace}\"} < 1"
      "for" = "15m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "paperless has had no available replica for 15m"
        description = "The archive is unreachable: check the pod, its three claims and the broker."
      }
    },
    {
      alert = "DocumentsAppRestarting"
      expr  = "increase(kube_pod_container_status_restarts_total{namespace=\"${var.namespace}\"}[1h]) > 3"
      "for" = "10m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "{{ $labels.pod }} is restarting repeatedly in documents"
        description = "{{ $value | humanize }} restarts in an hour; the logs will show whether it is OCR, the broker or a claim."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = var.name
      namespace = kubernetes_namespace_v1.this.metadata[0].name

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = var.name
        rules = local.app_alerts
      }]
    }
  })
}
