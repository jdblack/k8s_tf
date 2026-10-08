locals {
  rules = [
    {
      alert = "VeleroBackupStale"
      expr  = "time() - velero_backup_last_successful_timestamp{schedule!=\"\"} > 26 * 3600"
      "for" = "30m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "Velero schedule {{ $labels.schedule }} has not completed a backup in 26h"
        description = "Last success was {{ $value | humanizeDuration }} ago, so this volume's export chain has stopped."
      }
    },
    {
      alert = "VeleroBackupFailures"
      expr  = "increase(velero_backup_failure_total{schedule!=\"\"}[26h]) > 0"
      "for" = "10m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "Velero failed {{ $value | humanize }} backup(s) for {{ $labels.schedule }} in 26h"
        description = "Check `velero backup get` and the velero pod logs."
      }
    },
    {
      alert = "VeleroBackupItemErrors"
      expr  = "increase(velero_backup_items_errors{schedule!=\"\"}[26h]) > 0"
      "for" = "10m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "Velero reported item errors for {{ $labels.schedule }}"
        description = "The backup completed with per-item failures, so a restore may be incomplete."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "velero"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "velero"
        rules = local.rules
      }]
    }
  })
}
