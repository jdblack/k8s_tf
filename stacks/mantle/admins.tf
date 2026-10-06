# One group that is a member of every <app>-admin group: adding a user here makes authentik
# treat them as a member of each, so they get admin on every app. It is a new group on
# purpose -- `authentik Admins` is superuser and `platform`/`storage` gate whisker and
# seaweedfs-admin. Nesting only propagates child -> parent, so `parents` is the right side.
resource "authentik_group" "admin" {
  name = "admin"

  parents = concat(
    values(module.media.admin_group_ids),
    [
      module.seaweedfs_admin.admin_group_id,
      module.whisker.admin_group_id,
      module.alertmanager.admin_group_id,
      module.argo_setup.argocd_admin_group_id,
      module.argo_setup.argo_workflows_admin_group_id,
      module.grafana_oidc.admin_group_id,
      module.harbor_setup.admin_group_id,
      module.documents.owncloud_admin_group_id,
      module.pastebin.admin_group_id,
      module.vaultwarden.admin_group_id,
    ],
  )
}
