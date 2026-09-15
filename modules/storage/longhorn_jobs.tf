# Recurring snapshots for every Longhorn-backed PVC in the cluster.
#
# The job -> volume join is a LABEL on the Longhorn Volume CR (RecurringJob.spec
# has `groups`; there is no volume list), and a PVC carrying ANY recurring-job
# label REPLACES the volume's whole set -- so exactly one writer of those labels
# exists (snapshot_labeler.tf) and no PVC in this repo sets them at all.
#
# No backupTarget is configured, so these snapshots live on the same disks as the
# volume: RECOVERY, not backup. See modules/storage/disaster_recovery.md.
locals {
  # Longhorn only prunes once retain is exceeded, and skips a run when the volume
  # head has not changed -- so these are data-changing runs, not calendar days.
  snapshot_retain = {
    daily   = 2
    weekly  = 2
    monthly = 2
  }

  # Enrolment table: <namespace>/<pvc> => groups. Every Longhorn volume must appear
  # here, either with groups or as "skip"; disaster_recovery.md asserts that.
  snapshot_groups = {
    # Identity / catalog state: hand-built, not reconstructible from elsewhere.
    "kube-auth/data-authentik-postgresql-0"     = ["daily", "weekly", "monthly"]
    "kube-storage/data-filer-seaweedfs-filer-0" = ["daily", "weekly", "monthly"]
    "vaultwarden/vaultwarden-data"              = ["daily", "weekly", "monthly"]

    # Infra state: rebuildable, but slow and fiddly to recreate by hand.
    "devops-harbor/database-data-harbor-database-0" = ["weekly", "monthly"]
    "monitoring/prometheus-grafana"                 = ["weekly", "monthly"]

    # Thin, hand-edited UI config: re-pointing the app is minutes of work.
    "kube-storage/admin-data-seaweedfs-admin-0" = ["monthly"]
    "media/bazarr-config"                       = ["monthly"]
    "media/prowlarr-config"                     = ["monthly"]

    # "skip" is a real group with no job behind it, so the volume reads as
    # deliberately excluded rather than forgotten.
    "devops-harbor/data-harbor-redis-0"                 = ["skip"]
    "devops-harbor/harbor-jobservice"                   = ["skip"]
    "kube-storage/data-kube-storage-seaweedfs-master-0" = ["skip"]
    "media/qbittorrent-data"                            = ["skip"]
    "media/sonarr-config"                               = ["skip"]
    "media/radarr-config"                               = ["skip"]
    "media/pms-config-plex-plex-media-server-0"         = ["skip"]
  }

  # Groups the labeler may have to remove: the built-in `default` plus every group
  # this repo has ever set, so a volume that migrates tier is cleaned up, not
  # stacked.
  snapshot_known_groups = ["default", "daily", "weekly", "monthly", "skip", "vaultwarden"]
}

# NEVER put "default" in spec.groups: Longhorn auto-labels every unlabelled volume
# recurring-job-group.longhorn.io/default=enabled, so a default group would quietly
# enrol the skipped volumes.
resource "kubectl_manifest" "snapshot_job" {
  for_each = local.snapshot_retain

  yaml_body = yamlencode({
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "snapshot-${each.key}"
      namespace = var.longhorn_namespace
    }
    spec = {
      name = "snapshot-${each.key}"
      task = "snapshot"

      # Longhorn's cron is UTC; tiers are an hour apart and monthly runs on the
      # 28th because every month has a 28th.
      cron = {
        daily   = "0 3 * * *"
        weekly  = "0 4 * * 0"
        monthly = "0 5 28 * *"
      }[each.key]

      retain      = each.value
      groups      = [each.key]
      concurrency = 2

      # No `parameters`: for the snapshot task they surface nowhere useful, so the
      # tier of a snapshot is told by creation time when recovering.
    }
  })

  # kubectl_manifest, not kubernetes_manifest: longhorn.io's CRDs come from the
  # release in the same apply run (same reason as snapshots.tf).
  depends_on = [helm_release.longhorn]
}
