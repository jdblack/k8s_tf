
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

