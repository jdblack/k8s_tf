terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "deployment"
    config_path = "~/.kube/config"
  }
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.12.4"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "3.0.1"
    }
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

data kubernetes_secret_v1 argocd_auth {
  metadata {
    namespace = var.argo_namespace
    name = var.argo_auth_secret
  }
}


provider argocd {
  server_addr = "${var.argo_cd_server}:443"
  username = "admin"
  password = data.kubernetes_secret_v1.argocd_auth.data["password"]
}

