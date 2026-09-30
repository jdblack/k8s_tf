terraform {
  backend "kubernetes" {
    namespace     = "kube-system"
    secret_suffix = "mantle"
    config_path   = "~/.kube/config"
  }

  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.4.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.5"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.17.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.1"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "authentik" {
  url   = var.deployment.auth.server
  token = data.kubernetes_secret_v1.authentik_auth.data["api_key"]
}

provider "harbor" {
  username = data.kubernetes_secret_v1.harbor_auth.data["username"]
  password = data.kubernetes_secret_v1.harbor_auth.data["password"]
  url      = data.kubernetes_secret_v1.harbor_auth.data["url"]
}

provider "argocd" {
  server_addr = "${var.deployment.argo.server}.${var.deployment.cluster.domains.private}:443"
  username    = "admin"
  password    = data.kubernetes_secret_v1.argocd_auth.data["password"]
}
