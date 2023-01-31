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

