resource random_password harbor_oidc_pass {
  length = 15
  special = true
  override_special = "_%@"
}


resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = false
  oidc_name          = "Keycloak authentication"
  oidc_endpoint      = local.oidc_endpoint
  oidc_client_id     = local.oidc_name
  oidc_client_secret = random_password.harbor_oidc_pass.result
  oidc_scope         = "openid,email,groups"
  oidc_group_filter  = "/harbor.*"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "name"
  oidc_groups_claim   = "groups"
  oidc_admin_group   = "/harbor-admin"
}


# Keycloak client start
resource keycloak_openid_client oidc {
  realm_id = var.realm
  client_id = local.oidc_name
  name = "Harbor Authentication"
  enabled = true
  client_secret = random_password.harbor_oidc_pass.result
  root_url = local.url
  web_origins = [
    local.url,
    "https://${var.name}",
  ]
  access_type = "CONFIDENTIAL"
  valid_post_logout_redirect_uris = [ "*" ]
  valid_redirect_uris = [ local.oidc_callback ]
  standard_flow_enabled = true
  direct_access_grants_enabled = true
}

resource keycloak_openid_client_default_scopes scopes {
  realm_id = var.realm
  client_id = keycloak_openid_client.oidc.id
  default_scopes = [ "groups", "email", "profile" ]
}
# Keycloak client end


/*
# But we also have to give it our CA cert so that we trust the keycloak cert
#data kubernetes_config_map local_ca {
  #  metadata {
    name = var.ca_cert_cm
    namespace = var.namespace
  }
}
#end
*/



