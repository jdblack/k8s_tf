
module auth {
  name = var.name
  redirect_uri = "https://${local.fqdn}/auth/callback"
  source = "../../../auth/authentik/oidc_provider"
}

resource kubernetes_config_map_v1_data argo_config {
  metadata {
    name = "argocd-cm"
    namespace = var.namespace
  }
  data = {
    "oidc.config" = yamlencode({
      "name" : "Authentik",
      "issuer": "https://${var.oauth2_server}/application/o/${var.name}/",
      "clientID" : module.auth.client_id,
      "clientSecret" : module.auth.client_secret,
      "requestedScopes" : ["openid", "profile", "email", "groups"],
      "rootCA": data.kubernetes_config_map_v1.local_ca.data["tls.crt"]
    })
  }
}

data kubernetes_config_map_v1 local_ca {
  metadata {
    name = var.cert_issuer
  }
}


