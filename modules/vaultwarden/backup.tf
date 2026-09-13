# Longhorn snapshot schedule for the vault volume.
#
# Snapshots are CLUSTER-LOCAL: they belong to the volume, so losing the cluster
# (or its disks) loses them too, and `tofu destroy` of this module takes the PVC
# -- and therefore the snapshots -- with it (the longhorn StorageClass is
# reclaimPolicy: Delete). That is the accepted v1 posture; making destruction
# survivable means pointing Longhorn's backupTarget at an offsite S3 endpoint
# and switching task to "backup". See the module README ("Backups") and the
# follow-up in TODO.md.
#
# kubectl_manifest, not kubernetes_manifest: longhorn.io's CRD is installed by
# core's Longhorn release, and kubectl_manifest plans fine regardless (same
# reason as modules/storage/snapshots.tf).
#
# The join to the volume is by GROUP, and the group has to be declared on the
# PVC (deployment.tf), not here: the job names the group, the PVC claims it.
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
