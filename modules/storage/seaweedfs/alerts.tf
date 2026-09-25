locals {
  rules = [
    {
      alert = "SeaweedFSNoMasterLeader"
      expr  = "sum(SeaweedFS_master_is_leader) != 1"
      "for" = "5m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "SeaweedFS has no master leader"
        description = "Either no master is elected or more than one claims leadership. S3 and the filer stop accepting writes."
      }
    },
    {
      alert = "SeaweedFSVolumeDiskError"
      expr  = "SeaweedFS_volumeServer_disk_error_status > 0"
      "for" = "5m"

      labels = { severity = "critical" }

      annotations = {
        summary     = "SeaweedFS volume server {{ $labels.node }} reports a disk error"
        description = "The volume server cannot use one of its data dirs; volumes on it are unavailable."
      }
    },
    {
      alert = "SeaweedFSVolumeIOErrors"
      expr  = "increase(SeaweedFS_volumeServer_storage_io_error_total[1h]) > 0"
      "for" = "10m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "SeaweedFS volume server {{ $labels.node }} had storage IO errors in the last hour"
        description = "Read or write errors on the volume dirs: watch for a failing disk."
      }
    },
    {
      alert = "SeaweedFSMasterLeaderChanges"
      expr  = "increase(SeaweedFS_master_leader_changes[1h]) > 2"
      "for" = "10m"

      labels = { severity = "warning" }

      annotations = {
        summary     = "SeaweedFS master leadership is flapping"
        description = "{{ $value | humanize }} leader changes in an hour: the masters cannot keep a stable quorum."
      }
    },
  ]
}

resource "kubectl_manifest" "alerts" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "seaweedfs"
      namespace = var.namespace

      # Prometheus only loads rules carrying the selector the chart sets.
      labels = { release = "prometheus" }
    }

    spec = {
      groups = [{
        name  = "seaweedfs"
        rules = local.rules
      }]
    }
  })
}
