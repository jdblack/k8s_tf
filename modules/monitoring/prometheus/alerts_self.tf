locals {
  # An alert with no severity cannot be routed deliberately, so this is how a new
  # rule announces that it needs a decision.
  rules = [
    {
      alert = "UnclassifiedAlertFiring"
      expr  = "count by (alertname) (ALERTS{alertstate=\"firing\", severity=\"\"}) > 0"
      "for" = "1h"

      labels = { severity = "info" }

      annotations = {
        summary     = "Alert {{ $labels.alertname }} is firing without a severity label"
        description = "It is not eligible for a phone. Give it a severity and route it on purpose."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts_self" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "alerting"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "alerting"
        rules = local.rules
      }]
    }
  })
}
