locals {
  # Individual media app groups -- one line per app so each is easy to add or drop, and so the
  # media umbrella below aggregates exactly the same set.
  media_admin_groups = [
    module.media.admin_group_ids["radarr"],
    module.media.admin_group_ids["sonarr"],
    module.media.admin_group_ids["bazarr"],
    module.media.admin_group_ids["prowlarr"],
    module.media.admin_group_ids["qbittorrent"],
    module.media.admin_group_ids["suggestarr"],
    module.media.admin_group_ids["seerr"],
    module.media.admin_group_ids["immich"],
  ]

  media_user_groups = [
    module.media.user_group_ids["radarr"],
    module.media.user_group_ids["sonarr"],
    module.media.user_group_ids["bazarr"],
    module.media.user_group_ids["prowlarr"],
    module.media.user_group_ids["qbittorrent"],
    module.media.user_group_ids["suggestarr"],
    module.media.user_group_ids["seerr"],
    module.media.user_group_ids["immich"],
  ]
}

# Media umbrella: a member of `media` inherits every media app's admin and user group, so one
# group grants the whole media stack.
resource "authentik_group" "media" {
  name    = "media"
  parents = concat(local.media_admin_groups, local.media_user_groups)
}
