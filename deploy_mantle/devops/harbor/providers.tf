
terraform {
  required_providers {
    harbor = {
      source = "goharbor/harbor"
    }
    keycloak = {
      source = "keycloak/keycloak"
    }
  }
}
