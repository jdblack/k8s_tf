
terraform {
  required_providers {
    harbor = {
      source = "goharbor/harbor"
      version = "3.10.17"
    }
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.0.0"
    }
  }
}
