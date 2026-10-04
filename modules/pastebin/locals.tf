locals {
  fqdn = "${var.name}.${var.domain}"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  data_pvc_name = "${var.name}-data"

  # authentik serves a provider under its application's slug, which is this module's name.
  oidc_issuer = "${var.oidc_issuer_base}/application/o/${var.name}/"

  # config.yaml supersedes the UI, so every security-relevant setting is reviewable here
  # rather than living in a database only the admin panel can see.
  config = {
    general = {
      appName         = var.app_name
      appUrl          = "https://${local.fqdn}"
      showHomePage    = "true"
      showAuthButtons = "true"
    }

    security = {
      sessionDuration = "30 days"
      secureCookies   = "true"

      # No self-signup, and no sharing without a session: an authentik user is the only
      # person who can create a share, while the share links themselves stay anonymous.
      allowRegistration          = "false"
      allowUnauthenticatedShares = "false"
    }

    oauth = {
      "oidc-enabled"       = "true"
      "oidc-discoveryUri"  = local.oidc_issuer
      "oidc-signOut"       = "true"
      "oidc-scope"         = "openid email profile groups"
      "oidc-usernameClaim" = "preferred_username"

      # The oidc_provider module binds the application to <name>-admin / <name>-user, so
      # those are the only groups that can authorize; the admin one also gets the panel.
      "oidc-rolePath"        = "groups"
      "oidc-roleAdminAccess" = "${var.name}-admin"

      "oidc-clientId"     = module.oidc.client_id
      "oidc-clientSecret" = module.oidc.client_secret

      # Leaves authentik as the only way in and drops the email/password form, which
      # has no account behind it anyway (registration is off, no local users).
      "disablePassword" = "true"
    }
  }
}
