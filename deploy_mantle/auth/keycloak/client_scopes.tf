
resource keycloak_openid_client_scope  openid_client_scope {
  realm_id = keycloak_realm.realm.id
  name = "groups"
  description = "the scope mapper"
  include_in_token_scope = true
  gui_order = 1
}


#resource "keycloak_openid_user_realm_role_protocol_mapper" "user_realm_role_mapper" {
#  realm_id  = keycloak_realm.realm.id
#  client_scope_id = keycloak_openid_client_scope.openid_client_scope.id
#  name      = "map roles to groups"
#  add_to_id_token = true
#  add_to_userinfo = true
#  multivalued = true
#  claim_name = "groups"
#}


resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id        = keycloak_realm.realm.id
  client_scope_id = keycloak_openid_client_scope.openid_client_scope.id
  name            = "group-membership-mapper"
  add_to_id_token = true
  add_to_userinfo = true

  claim_name = "groups"
}



#resource "keycloak_openid_user_property_protocol_mapper" "user" {
#  realm_id  = keycloak_realm.realm.id
#  client_id = keycloak_openid_client.k8s.id
#  name      = "username"
#
#  user_property = "username"
#  claim_name    = "name"
#}
#
#
