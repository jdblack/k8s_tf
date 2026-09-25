locals {
  rules = [
    {
      alert = "ExternalDNSSyncStale"
      expr  = "time() - external_dns_controller_last_sync_timestamp_seconds > 3600"
      "for" = "15m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "external-dns has not synced for an hour"
        description = "Hostnames added since then will not resolve until it reconciles again."
      }
    },
    {
      alert = "ExternalDNSSoftErrors"
      expr  = "external_dns_controller_consecutive_soft_errors > 0"
      "for" = "30m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "external-dns is reporting consecutive soft errors"
        description = "Reconciliation keeps failing, usually a denied Route53 or DNS API call."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "external-dns"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "external-dns"
        rules = local.rules
      }]
    }
  })
}
