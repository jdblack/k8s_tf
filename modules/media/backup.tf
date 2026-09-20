locals {
  # One schedule per PVC. `selector` finds the pod mounting it, which is how Velero learns the
  # claim; targets sharing a volume must exclude that volume or they capture each other.
  media_targets = {
    "sonarr-config"     = { selector = { "app.kubernetes.io/name" = "sonarr" }, tiers = ["daily", "weekly"] }
    "radarr-config"     = { selector = { "app.kubernetes.io/name" = "radarr" }, tiers = ["daily", "weekly"] }
    "prowlarr-config"   = { selector = { "app.kubernetes.io/name" = "prowlarr" }, tiers = ["daily", "weekly"] }
    "bazarr-config"     = { selector = { "app.kubernetes.io/name" = "bazarr" }, tiers = ["daily", "weekly"] }
    "seerr-config"      = { selector = { "app.kubernetes.io/name" = "seerr" }, tiers = ["daily", "weekly"] }
    "suggestarr-config" = { selector = { "app.kubernetes.io/name" = "suggestarr" }, tiers = ["daily", "weekly"] }
    "qbittorrent-data"  = { selector = { "app.kubernetes.io/name" = "qbittorrent" }, tiers = ["daily", "weekly"] }
    "plex-pms-config"   = { selector = { "app.kubernetes.io/name" = "plex-media-server" }, tiers = ["daily", "weekly"] }
  }
}

module "backup" {
  for_each = local.media_targets
  source   = "../storage/backup/schedule"

  target    = each.key
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  selector  = each.value.selector
  tiers     = each.value.tiers
}
