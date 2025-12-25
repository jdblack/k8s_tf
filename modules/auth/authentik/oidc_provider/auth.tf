
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
      url = var.redirect_uri
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

