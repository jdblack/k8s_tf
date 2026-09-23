locals {
  # One schedule per PVC. `selector` finds the pod mounting it, which is how Velero learns the
  # claim; targets sharing a volume must exclude that volume or they capture each other.
  media_targets = {
    "sonarr-config"     = { "app.kubernetes.io/name" = "sonarr" }
    "radarr-config"     = { "app.kubernetes.io/name" = "radarr" }
    "prowlarr-config"   = { "app.kubernetes.io/name" = "prowlarr" }
    "bazarr-config"     = { "app.kubernetes.io/name" = "bazarr" }
    "seerr-config"      = { "app.kubernetes.io/name" = "seerr" }
    "suggestarr-config" = { "app.kubernetes.io/name" = "suggestarr" }
    "qbittorrent-data"  = { "app.kubernetes.io/name" = "qbittorrent" }
    "plex-pms-config"   = { "app.kubernetes.io/name" = "plex-media-server" }
    "immich-postgres"   = { "app.kubernetes.io/name" = "immich-postgres" }
  }
}

module "backup" {
  for_each = local.media_targets
  source   = "../storage/backup/schedule"

  target    = each.key
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  selector  = each.value
}
