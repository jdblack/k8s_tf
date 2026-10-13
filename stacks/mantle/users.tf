# User-tier counterpart to `admin`: membership in `user` grants the user role of the
# selected apps. Points at <app>-user groups, so it composes the same way as `admin`.
resource "authentik_group" "user" {
  name = "user"

  parents = concat(
    local.media_user_groups,
    [
      module.pastebin.user_group_id,
      data.authentik_group.forgejo_user.id,
      module.documents.owncloud_user_group_id,
      module.vaultwarden.user_group_id,
    ],
  )
}
