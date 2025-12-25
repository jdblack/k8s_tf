
module oauth2 {
  name = var.name
  domain = var.domain
  oauth2_host = "auth.vn.linuxguru.net"
  cert_issuer = var.cert_issuer
  redirect_uri = "https://${local.fqdn}/c/oidc/callback"
  source = "../../auth/authentik/oidc_provider"
}



resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = false
  oidc_name          = "Authentik"
  oidc_endpoint      = "https://${var.oauth2_server}/application/o/${var.name}/"
  oidc_client_id     = module.oauth2.client_id
  oidc_client_secret = module.oauth2.client_secret
  oidc_scope         = "openid,email,profile"
  oidc_group_filter  = "harbor.*"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim   = "groups"
  oidc_admin_group   = "harbor-admin"
}
