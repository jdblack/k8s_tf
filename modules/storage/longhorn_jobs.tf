# Recurring snapshots for every Longhorn-backed PVC in the cluster.
#
# WHY CORE, not per-app: snapshots belong to the Volume, and the join between a
# job and a volume is a LABEL on the Longhorn Volume CR -- RecurringJob.spec has
# `groups`, there is no volume list (checked against the v1beta2 CRD). Longhorn
# does NOT merge PVC labels with volume labels: a PVC carrying ANY recurring-job
# label REPLACES the volume's whole set, so a half-labelled PVC silently drops
# groups. Hence exactly one owner of these labels --
# modules/storage/snapshot_labeler.tf, writing Volume CRs -- and no PVC in this
# repo sets recurring-job.longhorn.io/* at all.
#
# Retention is uniform. Tiers are about how hard a volume is to rebuild
# (identity/catalog > infra state > thin UI config), never about the app.
#
# No backupTarget is configured, so these snapshots live on the same disks as the
# volume: this is RECOVERY, not backup. See modules/storage/disaster_recovery.md.
locals {
  # Longhorn prunes the oldest snapshot of a job only once retain is exceeded,
  # and skips a run outright when the volume head has not changed -- so these
  # counts are "data-changing runs", not calendar days.
  snapshot_retain = {
    daily   = 2
    weekly  = 2
    monthly = 2
  }

  # Enrolment table: <namespace>/<pvc> => groups. Every Longhorn volume in the
  # cluster must appear here, either with real groups or as "skip"; the coverage
  # audit in disaster_recovery.md asserts exactly that.
  snapshot_groups = {
    # Identity / catalog state: hand-built, not reconstructible from elsewhere.
    # vaultwarden is here on merit, not sentiment -- every client keeps a full
    # copy of the vault, so a restore there is usually a last resort.
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

    # Skipped on purpose. "skip" is a real group with no job behind it, so the
    # volume reads as deliberately excluded rather than forgotten.
    "devops-harbor/data-harbor-redis-0"                 = ["skip"]
    "devops-harbor/harbor-jobservice"                   = ["skip"]
    "kube-storage/data-kube-storage-seaweedfs-master-0" = ["skip"]
    "media/qbittorrent-data"                            = ["skip"]
    "media/sonarr-config"                               = ["skip"]
    "media/radarr-config"                               = ["skip"]
    "media/pms-config-plex-plex-media-server-0"         = ["skip"]
  }

  # Universe of group labels the labeler may have to remove: the built-in
  # `default` plus every group this repo has ever set, so a volume that migrates
  # between tiers (or off a retired per-app group) is cleaned up, not stacked.
  snapshot_known_groups = ["default", "daily", "weekly", "monthly", "skip", "vaultwarden"]
}

# NEVER put "default" in spec.groups: Longhorn auto-labels every unlabelled
# volume recurring-job-group.longhorn.io/default=enabled, so a default group
# would quietly enrol the 7 skipped volumes. The audit greps for this.
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

      # Longhorn's cron is UTC. Tiers are an hour apart, and monthly runs on the
      # 28th because every month has a 28th.
      cron = {
        daily   = "0 3 * * *"
        weekly  = "0 4 * * 0"
        monthly = "0 5 28 * *"
      }[each.key]

      retain      = each.value
      groups      = [each.key]
      concurrency = 2

      # No `parameters`: for the snapshot task they do not surface anywhere
      # useful (verified -- neither a bare key nor `labels: "k=v"` reaches the
      # snapshot CR's labels), so the tier is identified by creation time when
      # recovering. See modules/storage/disaster_recovery.md.
    }
  })

  # kubectl_manifest, not kubernetes_manifest: longhorn.io's CRDs are installed
  # by the release in the same apply run (same reason as snapshots.tf).
  depends_on = [helm_release.longhorn]
}
