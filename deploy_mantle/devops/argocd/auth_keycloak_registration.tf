
# Secret Start : Here we set up a secret between argocd and keycloak
resource random_password argo_client {
  length = 15
  special = true
  override_special = "_%@"
}

resource kubernetes_secret_v1_data argo_secrets {
  metadata {
    name = "argocd-secret"
    namespace = var.namespace
  }
  data = {
    "oidc.keycloak.clientSecret" = random_password.argo_client.result
  }
}
# Secret End


# Keycloak client start
resource keycloak_openid_client argocd {
  realm_id = var.realm
  client_id = "argocd_auth"
  name = "Argocd Authentication"
  enabled = true
  client_secret = random_password.argo_client.result
  root_url = "https://${var.argo_host}.${var.domain}"
  web_origins = [
    "https://${var.argo_host}",
    "https://${var.argo_host}.${var.domain}"
  ]
  access_type = "CONFIDENTIAL"
  valid_post_logout_redirect_uris = [ "*" ]
  valid_redirect_uris = [
    "https://${var.argo_host}.${var.domain}/*"
  ]
  standard_flow_enabled = true
  direct_access_grants_enabled = true
}

resource keycloak_openid_client_default_scopes argo_scopes {
  realm_id = var.realm
  client_id = keycloak_openid_client.argocd.id
  default_scopes = [ "groups", "email", "profile" ]
}
# Keycloak client end



# start This teaches argocd how to talk to keycloak
resource kubernetes_config_map_v1_data argo_config {
  metadata {
    name = "argocd-cm"
    namespace = var.namespace
  }
  data = {
    "oidc.config" = yamlencode({
      "name" : "Keycloak",
      "issuer": var.keycloak_url,
      "clientID" : "argocd_auth",
      "clientSecret" : "$oidc.keycloak.clientSecret",
      "requestedScopes" : ["openid", "profile", "email", "groups"],
      "rootCA": data.kubernetes_config_map_v1.local_ca.data["ca.crt"]
    })
  }
}

# But we also have to give it our CA cert so that we trust the keycloak cert
data kubernetes_config_map_v1 local_ca {
  metadata {
    name = var.ca_cert_cm
    namespace = var.namespace
  }
}
#end



