locals {
  # The exporter reports a pod, not a node; alerts that cannot name a host are not
  # worth sending, so every expression joins kube_pod_info on the way through.
  by_node = "on (namespace, pod) group_left(node) kube_pod_info{namespace=\"${var.namespace}\"}"

  rules = [
    {
      alert = "SmartDeviceHealthFailing"
      expr  = "(max_over_time(smartctl_device_smart_status[15m]) * ${local.by_node}) != 1"
      "for" = "10m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} is failing its SMART health check"
        description = "smartctl reports a failed overall-health self-assessment. Copy the data off and replace the disk."
      }
    },
    {
      alert = "SmartDeviceCriticalWarning"
      expr  = "(max_over_time(smartctl_device_critical_warning[15m]) * ${local.by_node}) > 0"
      "for" = "10m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} raised an NVMe critical warning"
        description = "Critical warning bits set: {{ $value }}. Usually spare capacity or reliability exhausted."
      }
    },
    {
      alert = "SmartDeviceMediaErrors"
      expr  = "(delta(smartctl_device_media_errors[6h]) * ${local.by_node}) > 0"
      "for" = "5m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} logged new media errors in the last 6h"
        description = "Uncorrectable read/write errors are accumulating. Check the cable, then the disk."
      }
    },
    {
      alert = "SmartDevicePercentageUsedHigh"
      expr  = "(smartctl_device_percentage_used * ${local.by_node}) > 90"
      "for" = "1h"

      labels = { severity = "warning" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} is {{ $value }}% through its rated writes"
        description = "NVMe endurance is nearly spent. Plan a replacement."
      }
    },
    {
      alert = "SmartDeviceAvailableSpareLow"
      expr  = "((smartctl_device_available_spare - smartctl_device_available_spare_threshold) * ${local.by_node}) < 0"
      "for" = "1h"

      labels = { severity = "warning" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} spare blocks are below the vendor threshold"
        description = "Available spare has fallen under the NVMe threshold: writes will start to slow, failure follows."
      }
    },
    {
      alert = "SmartDeviceTemperatureHigh"
      expr  = "(smartctl_device_temperature * ${local.by_node}) > 65"
      "for" = "30m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "{{ $labels.node }}: /dev/{{ $labels.device }} is at {{ $value }}C"
        description = "Sustained temperature above 65C throttles the disk and shortens its life."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "smart"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "smart"
        rules = local.rules
      }]
    }
  })
}
