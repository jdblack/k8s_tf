module "auth" {
  name         = var.name
  redirect_uri = "https://${local.fqdn}/auth/callback"
  source       = "../../../auth/authentik/oidc_provider"

  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/argo-cd.svg"
  open_in_new_tab = true

  # Only argo-cd-admin and argo-cd-user may sign in, matching the RBAC policy.csv.
  bind_app = true
}

resource "kubernetes_config_map_v1_data" "argo_config" {
  metadata {
    name      = "argocd-cm"
    namespace = var.namespace
  }
  data = {
    "oidc.config" = yamlencode({
      "name" : "Authentik",
      "issuer" : "https://${var.oauth2_server}/application/o/${var.name}/",
      "clientID" : module.auth.client_id,
      "clientSecret" : module.auth.client_secret,
      "requestedScopes" : ["openid", "profile", "email", "groups"]
    })
  }
}
