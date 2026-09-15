# Recurring snapshots for every Longhorn-backed PVC. The job -> volume join is a label on
# the Volume CR (why snapshot_labeler.tf is its only writer, and why no PVC sets those
# labels). No backupTarget: RECOVERY, not backup -- storage/disaster_recovery.md.
locals {
  # Longhorn prunes only past retain and skips an unchanged volume head.
  snapshot_retain = {
    daily   = 2
    weekly  = 2
    monthly = 2
  }

  # <namespace>/<pvc> => groups; every volume must appear, groups or "skip".
  snapshot_groups = {
    "kube-auth/data-authentik-postgresql-0"     = ["daily", "weekly", "monthly"]
    "kube-storage/data-filer-seaweedfs-filer-0" = ["daily", "weekly", "monthly"]
    "vaultwarden/vaultwarden-data"              = ["daily", "weekly", "monthly"]

    "devops-harbor/database-data-harbor-database-0" = ["weekly", "monthly"]
    "monitoring/prometheus-grafana"                 = ["weekly", "monthly"]

    "kube-storage/admin-data-seaweedfs-admin-0" = ["monthly"]
    "media/bazarr-config"                       = ["monthly"]
    "media/prowlarr-config"                     = ["monthly"]

    # "skip" = excluded on purpose (a real group with no job behind it).
    "devops-harbor/data-harbor-redis-0"                 = ["skip"]
    "devops-harbor/harbor-jobservice"                   = ["skip"]
    "kube-storage/data-kube-storage-seaweedfs-master-0" = ["skip"]
    "media/qbittorrent-data"                            = ["skip"]
    "media/sonarr-config"                               = ["skip"]
    "media/radarr-config"                               = ["skip"]
    "media/pms-config-plex-plex-media-server-0"         = ["skip"]
  }

  # Removed from migrated volumes: built-in `default` + every group ever used.
  snapshot_known_groups = ["default", "daily", "weekly", "monthly", "skip", "vaultwarden"]
}

# NEVER list "default" in spec.groups: Longhorn auto-labels every unlabelled volume into
# it, which would quietly enrol the skipped ones.
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

      # UTC; the 28th because every month has one.
      cron = {
        daily   = "0 3 * * *"
        weekly  = "0 4 * * 0"
        monthly = "0 5 28 * *"
      }[each.key]

      retain      = each.value
      groups      = [each.key]
      concurrency = 2
    }
  })

  # CRDs come from the release in the same apply (as in snapshots.tf).
  depends_on = [helm_release.longhorn]
}
