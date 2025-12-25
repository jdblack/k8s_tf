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
      version = "5.5.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    harbor = {
      source = "goharbor/harbor"
      version = "3.10.17"
    }

    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.12.4"
    }

    authentik = {
      source = "goauthentik/authentik"
      version = "2025.10.1"
    }


  }
}

data kubernetes_secret_v1 keycloak_auth {
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
  username  = data.kubernetes_secret_v1.keycloak_auth.data["admin_user"]
  password  = data.kubernetes_secret_v1.keycloak_auth.data["admin_password"]
  url       = data.kubernetes_secret_v1.keycloak_auth.data["admin_url"]
}


data kubernetes_secret_v1 harbor_auth {
  metadata {
    namespace = var.deployment.harbor.namespace
    name = var.deployment.harbor.auth_secret
  }
}

data kubernetes_secret_v1 authentik_auth {
  metadata {
    namespace = var.deployment.auth.namespace
    name = var.deployment.auth.authentik_api_key
  }

}

provider authentik {
  url = var.deployment.auth.server
  token = data.kubernetes_secret_v1.authentik_auth.data["api_key"]
}

provider harbor {
  username = data.kubernetes_secret_v1.harbor_auth.data["username"]
  password = data.kubernetes_secret_v1.harbor_auth.data["password"]
  url = data.kubernetes_secret_v1.harbor_auth.data["url"]
}

data kubernetes_secret_v1 argocd_auth {
  metadata {
    namespace = var.deployment.argocd_devops.namespace
    name = var.deployment.argocd_devops.auth_secret
  }
}

provider "argocd" {
  server_addr = "${var.deployment.argocd_devops.server}:443"
  username = "admin"
  password = data.kubernetes_secret_v1.argocd_auth.data["password"]
}

