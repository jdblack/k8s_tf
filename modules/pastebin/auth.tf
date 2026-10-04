# Native OIDC, not the authentik proxy outpost: the outpost 302s anonymous visitors into
# the login flow, which would break the public share links the whole point rests on.
module "oidc" {
  source = "../auth/authentik/oidc_provider"

  name         = var.name
  redirect_uri = "https://${local.fqdn}/api/oauth/callback/oidc"

  # Post-logout redirect the provider is handed on sign-out.
  extra_redirect_uris = ["https://${local.fqdn}"]

  # Creates and binds <name>-admin and <name>-user, so only those groups may sign in.
  bind_app = true

  # pingvin-share refuses an id_token whose email_verified is false, which is what
  # authentik's built-in email mapping always sends.
  email_verified = true

  meta_launch_url = "https://${local.fqdn}"
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/pingvin-share.svg"
  open_in_new_tab = true
}
