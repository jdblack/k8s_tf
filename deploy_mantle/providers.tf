terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "mantle"
    config_path = "~/.kube/config"
  }
}


terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.0.0"
    }
  }
}

data kubernetes_secret keycloak_auth {
  metadata {
    namespace = var.deployment.keycloak.namespace
    name = var.deployment.keycloak.credentials
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}

provider "keycloak" {
  client_id = "admin-cli"
  username  = data.kubernetes_secret.keycloak_auth.data["admin_user"]
  password  = data.kubernetes_secret.keycloak_auth.data["admin_password"]
  url       = data.kubernetes_secret.keycloak_auth.data["admin_url"]
}


