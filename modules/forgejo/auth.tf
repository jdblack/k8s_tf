# Native OIDC, not the authentik proxy outpost: the source is registered against this
# callback and the group claim drives admin/restricted, so no outpost is involved.
module "oidc" {
  source = "../auth/authentik/oidc_provider"

  name         = var.name
  redirect_uri = "https://${local.fqdn}/user/oauth2/${local.oidc_source_name}/callback"

  # The login flow returns to the site root after sign-out.
  extra_redirect_uris = ["https://${local.fqdn}"]

  # Creates and binds <name>-admin and <name>-user; the source maps those onto Forgejo roles.
  bind_app = true

  meta_launch_url = "https://${local.fqdn}"
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/forgejo.svg"
  open_in_new_tab = true
}
