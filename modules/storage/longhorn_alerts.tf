locals {
  rules = [
    {
      alert = "LonghornVolumeDegraded"
      expr  = "longhorn_volume_robustness{state=\"degraded\"} == 1"
      "for" = "15m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "Longhorn volume {{ $labels.pvc }} is degraded"
        description = "{{ $labels.volume }} on {{ $labels.node }} is missing a healthy replica: fewer copies of the data than intended."
      }
    },
    {
      alert = "LonghornVolumeFaulted"
      expr  = "longhorn_volume_robustness{state=\"faulted\"} == 1"
      "for" = "5m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "Longhorn volume {{ $labels.pvc }} is faulted"
        description = "{{ $labels.volume }} on {{ $labels.node }} has no usable replica. The workload is down until a replica recovers."
      }
    },
    {
      alert = "LonghornVolumeUnknown"
      expr  = "longhorn_volume_robustness{state=\"unknown\"} == 1"
      "for" = "1h"

      labels = { severity = "warning" }

      annotations = {
        summary     = "Longhorn cannot determine the state of {{ $labels.pvc }}"
        description = "{{ $labels.volume }} has reported unknown robustness for an hour: usually the instance manager is gone."
      }
    },
    {
      # Longhorn stops scheduling at its default 25% reserved, so 80% used is late.
      alert = "LonghornDiskSpaceLow"
      expr  = "longhorn_disk_usage_bytes / longhorn_disk_capacity_bytes > 0.8"
      "for" = "30m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "Longhorn disk {{ $labels.disk }} on {{ $labels.node }} is {{ $value | humanizePercentage }} full"
        description = "Above 80% Longhorn stops accepting new replicas on this disk."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "longhorn"
      namespace = var.longhorn_namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "longhorn"
        rules = local.rules
      }]
    }
  })
}
