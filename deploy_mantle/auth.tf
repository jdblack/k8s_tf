

module keycloak {
  source = "./auth/keycloak"
  realm = var.deployment.keycloak.realm
  realm_display = var.deployment.keycloak.realm_display
  providers = {
    keycloak = keycloak
  }
}
