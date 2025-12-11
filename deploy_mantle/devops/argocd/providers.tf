
terraform {
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.12.1"
    }
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.0.0"
    }
  }
}


