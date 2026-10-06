module "auth" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/oauth2/callback"
  source       = "../../../auth/authentik/oidc_provider"

  meta_icon       = "https://avatars.githubusercontent.com/u/30269780?s=60&v=4"
  open_in_new_tab = true

  # Only argo-wf-admin and argo-wf-user may sign in, matching the ui_admin_access rule.
  bind_app = true
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
