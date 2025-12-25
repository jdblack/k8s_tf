
data authentik_certificate_key_pair cert {
    name = "tls"
  }


data authentik_flow default-authorization-flow {
  slug = "default-provider-authorization-implicit-consent"
}

data authentik_flow default-provider-invalidation-flow {
  slug = "default-provider-authorization-implicit-consent"
}

data authentik_property_mapping_provider_scope email {
  scope_name = "email"
}

data authentik_property_mapping_provider_scope profile {
  scope_name = "profile"
}
data authentik_property_mapping_provider_scope openid {
  scope_name = "openid"
}


resource  authentik_provider_oauth2 oauth2  {
  name = var.name
  client_id = var.name
  invalidation_flow = data.authentik_flow.default-provider-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key = data.authentik_certificate_key_pair.cert.id
  #  encryption_key = data.authentik_certificate_key_pair.cert.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]

  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url = "https://argo.${var.domain}/auth/callback"
    }
  ]

}

resource authentik_group admin {
  name = "${var.name}-admin"
}

resource authentik_group user {
  name = "${var.name}-user"
}

resource authentik_application app {
  name = var.name
  slug = var.name
  protocol_provider = authentik_provider_oauth2.oauth2.id
}

resource kubernetes_config_map_v1_data argo_config {
  metadata {
    name = "argocd-cm"
    namespace = var.namespace
  }
  data = {
    "oidc.config" = yamlencode({
      "name" : "Authentik",
      "issuer": "https://${var.oauth2_host}/application/o/${var.name}/", 
      "clientID" : authentik_provider_oauth2.oauth2.client_id,
      "clientSecret" : authentik_provider_oauth2.oauth2.client_secret,
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

