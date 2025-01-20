
terraform {
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.3.0"
    }
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.0.0"
    }
  }
}


