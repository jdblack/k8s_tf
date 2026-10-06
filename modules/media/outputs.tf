output "admin_group_ids" {
  value = {
    radarr      = module.radarr.admin_group_id
    sonarr      = module.sonarr.admin_group_id
    bazarr      = module.bazarr.admin_group_id
    prowlarr    = module.prowlarr.admin_group_id
    qbittorrent = module.qbittorrent.admin_group_id
    suggestarr  = module.suggestarr.admin_group_id
    seerr       = module.seerr_tile.admin_group_id
    immich      = module.immich.admin_group_id
  }
}

output "user_group_ids" {
  value = {
    seerr  = module.seerr_tile.user_group_id
    immich = module.immich.user_group_id
  }
}
