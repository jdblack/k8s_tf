# Longhorn snapshot schedule for the vault volume. Snapshots are CLUSTER-LOCAL
# (they belong to the volume), and the longhorn StorageClass is
# reclaimPolicy: Delete -- so losing the cluster or destroying this module takes
# them too. Accepted v1 posture; see the module README and TODO.md.
#
# kubectl_manifest, not kubernetes_manifest: longhorn.io's CRD is installed by
# core's Longhorn release, and kubectl_manifest plans fine regardless (same as
# modules/storage/snapshots.tf).
#
# The join to the volume is by GROUP, declared on the PVC (deployment.tf): the
# job names the group, the PVC claims it.
resource "kubectl_manifest" "snapshot" {
  yaml_body = yamlencode({
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "${var.name}-snapshot"
      namespace = "longhorn-system"
    }
    spec = {
      name   = "${var.name}-snapshot"
      task   = "snapshot"
      cron   = "0 3 * * *"
      retain = 7

      # The join to the volume: matches the
      # recurring-job-group.longhorn.io/<group> label on the PVC.
      groups = [local.snapshot_group]

      concurrency = 2
    }
  })
}
