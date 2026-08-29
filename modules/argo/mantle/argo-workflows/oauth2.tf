
module "auth" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/oauth2/callback"
  source       = "../../../auth/authentik/oidc_provider"
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
