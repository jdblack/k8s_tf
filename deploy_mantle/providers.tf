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
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.18.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    harbor = {
      source = "goharbor/harbor"
      version = "3.10.17"
    }

    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.11.2"
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

provider "helm" {
  kubernetes = { 
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}


provider "keycloak" {
  client_id = "admin-cli"
  username  = data.kubernetes_secret.keycloak_auth.data["admin_user"]
  password  = data.kubernetes_secret.keycloak_auth.data["admin_password"]
  url       = data.kubernetes_secret.keycloak_auth.data["admin_url"]
}


data kubernetes_secret harbor_auth {
  metadata {
    namespace = var.deployment.harbor.namespace
    name = var.deployment.harbor.auth_secret
  }
}

provider harbor {
  username = data.kubernetes_secret.harbor_auth.data["username"]
  password = data.kubernetes_secret.harbor_auth.data["password"]
  url = data.kubernetes_secret.harbor_auth.data["url"]
}

data kubernetes_secret argocd_auth {
  metadata {
    namespace = var.deployment.argocd_devops.namespace
    name = var.deployment.argocd_devops.auth_secret
  }
}

provider "argocd" {
  server_addr = "${var.deployment.argocd_devops.server}:443"
  username = "admin"
  password = data.kubernetes_secret.argocd_auth.data["password"]
}

