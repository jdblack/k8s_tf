
terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.18.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.35.1"
    }
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

provider "keycloak" {
  client_id = "admin-cli"
  username = data.kubernetes_secret.keycloak_auth.admin_user
  password = data.kubernetes_secret.keycloak_auth.admin_password
  url      = data.kubernetes_secret.keycloak_auth.admin_user
  password = module.keycloak.admin_pass
  url = module.keycloak.admin_url
}


provider "kubernetes" {
  config_path    = "~/.kube/config"
}


provider "helm" {
  kubernetes { 
    config_path = "~/.kube/config"
  }
}


provider "kubectl" {
  config_path = "~/.kube/config"
}



