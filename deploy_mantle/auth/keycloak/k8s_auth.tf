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

#
#
#resource kubectl_manifest  authenticate_with_keycloak
#  yaml_body = <<EOT
#apiVersion: apiserver.config.k8s.io/v1beta1
#kind: AuthenticationConfiguration
#jwt:
#- issuer:
#    url: "https://keycloak.vn.linuxguru.net/auth/realms/${var.realm}"
#    audiences:
#    - "k8s_auth"  # Your clientId from Keycloak
#  claimMappings:
#    username:
#      claim: "sub"  # This may need to be adjusted if your Keycloak setup uses a different claim
#      prefix: ""  # Adjust if you need prefixes for usernames
#    groups:
#      claim: "groups"  # Adjust based on how you configure groups in Keycloak
#      prefix: ""  # Adjust if you need prefixes for groups
#    uid:
#      claim: "sub"  # This typically identifies the user
#  userValidationRules:
#  - expression: "!user.username.startsWith('system:')"  # Ensure usernames do not start with system:
#    message: "Username cannot use the reserved system: prefix"
#EOT
#
#
