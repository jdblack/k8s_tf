module "auth" {
  source = "../../auth/authentik/oidc_provider"

  name         = var.name
  redirect_uri = "https://${local.fqdn}/auth/login"

  # The mobile app signs in through its own callback scheme, not the browser.
  extra_redirect_uris = [
    "https://${local.fqdn}/user-settings",
    "app.immich:///oauth-callback",
  ]

  bind_app = true

  meta_icon       = local.icon
  open_in_new_tab = true
}
