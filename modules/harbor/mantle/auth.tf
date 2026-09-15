
module "oauth2" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/c/oidc/callback"
  source       = "../../auth/authentik/oidc_provider"

  # Bookmark tile (dashboard-icons via jsDelivr) + open in a new tab.
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/harbor.svg"
  open_in_new_tab = true
}



resource "harbor_config_auth" "oidc" {
  auth_mode = "oidc_auth"
  # Skip the "Authentik vs local DB" login page and bounce straight to the OIDC
  # provider. Local DB login still exists -- the admin has to type the login url
  # (/account/sign-in) by hand. Harbor >= 2.8 (chart is unpinned, so fine).
  primary_auth_mode  = true
  oidc_name          = "Authentik"
  oidc_endpoint      = "https://${var.oauth2_server}/application/o/${var.name}/"
  oidc_client_id     = module.oauth2.client_id
  oidc_client_secret = module.oauth2.client_secret
  oidc_scope         = "openid,email,profile"
  oidc_group_filter  = "harbor.*"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "harbor-admin"
}
