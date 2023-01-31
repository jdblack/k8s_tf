resource "random_password" "client_pass" {
  length = 15
  special = true
  override_special = "_%@"
}

resource keycloak_openid_client grafana {
  realm_id = var.keycloak_realm
  client_id = var.name
  name = "Grafana authenticator"
  enabled = true
  access_type = "CONFIDENTIAL"
  direct_access_grants_enabled = true
  valid_redirect_uris = [
    "https://${local.fqdn}/*"
  ]
  standard_flow_enabled = true
  client_authenticator_type = "client-secret"
  client_secret = random_password.client_pass.result
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id  = var.keycloak_realm
  client_id = keycloak_openid_client.grafana.id
  name      = "groups"
  claim_name = "groups"
}


resource "keycloak_openid_user_property_protocol_mapper" "user" {
  realm_id  = var.keycloak_realm
  client_id = keycloak_openid_client.grafana.id
  name      = "username"

  user_property = "username"
  claim_name    = "name"
}

resource "keycloak_group" "grafana_admin" {
  realm_id = var.keycloak_realm
  name     = "grafana-admin"
}

resource "keycloak_group" "grafana_edit" {
  realm_id = var.keycloak_realm
  name     = "grafana-editor"
}


