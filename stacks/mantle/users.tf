# User-tier counterpart to `admin`: membership in `user` grants the user role of the
# selected apps. Points at <app>-user groups, so it composes the same way as `admin`.
resource "authentik_group" "user" {
  name = "user"

  parents = [
    module.media.user_group_ids["immich"],
    module.media.user_group_ids["seerr"],
    module.pastebin.user_group_id,
    module.documents.owncloud_user_group_id,
    module.vaultwarden.user_group_id,
  ]
}
