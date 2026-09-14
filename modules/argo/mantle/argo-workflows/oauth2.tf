# Authentik OIDC client for the Workflows UI SSO, and the k8s secret holding the
# client credentials the chart's server.sso config points at.
module "auth" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/oauth2/callback"
  source       = "../../../auth/authentik/oidc_provider"

  # Tile icon + open in a new tab. No dedicated Argo Workflows icon exists in the
  # dashboard-icons/selfh.st sets, so keep the official Argo Project GitHub avatar.
  meta_icon       = "https://avatars.githubusercontent.com/u/30269780?s=60&v=4"
  open_in_new_tab = true
}

resource "kubernetes_secret_v1" "oauth_secret" {
  metadata {
    namespace = var.namespace
    name      = local.sso_secret
  }
  data = {
    client_id = module.auth.client_id,
    secret    = module.auth.client_secret
  }
}
