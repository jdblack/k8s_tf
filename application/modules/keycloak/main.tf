
resource "keycloak_realm" "realm" {
  realm             = var.realm
  enabled           = true
  display_name      = var.realm_display
  display_name_html = "<b>Linuxguru.Net</b>"
  login_theme = "keycloak"
  access_token_lifespan = "1h"
  access_token_lifespan_for_implicit_flow = "1h"
  sso_session_idle_timeout = "24h"
  sso_session_idle_timeout_remember_me = "336h"
  sso_session_max_lifespan = "48h"
  sso_session_max_lifespan_remember_me = "720h"
}

resource keycloak_openid_client k8s {
  realm_id = keycloak_realm.realm.id
  client_id = "k8s_auth"
  name = "K8s Authentication"
  enabled = true
  access_type = "CONFIDENTIAL"
  valid_redirect_uris = [
    "http://localhost:8000",
    "http://localhost:18000"
  ]
  standard_flow_enabled = true

}


resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id  = keycloak_realm.realm.id
  client_id = keycloak_openid_client.k8s.id
  name      = "groups"
  claim_name = "groups"
}




resource "keycloak_openid_user_property_protocol_mapper" "user" {
  realm_id  = keycloak_realm.realm.id
  client_id = keycloak_openid_client.k8s.id
  name      = "username"

  user_property = "username"
  claim_name    = "name"
}

resource "keycloak_group" "clusteradmin" {
  realm_id = keycloak_realm.realm.id
  name     = "clusteradmin"
}
