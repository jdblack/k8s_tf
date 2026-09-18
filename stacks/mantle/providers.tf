terraform {
  backend "kubernetes" {
    namespace     = "kube-system"
    secret_suffix = "mantle"
    config_path   = "~/.kube/config"
  }

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.17"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.12.4"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
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

provider "aws" {
  access_key = var.deployment.cert.AWS_ACCESS_KEY_ID
  secret_key = var.deployment.cert.AWS_SECRET_ACCESS_KEY
  region     = var.deployment.cert.AWS_REGION
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
  server_addr = "${var.deployment.argocd_devops.server}.${var.deployment.common.domain}:443"
  username    = "admin"
  password    = data.kubernetes_secret_v1.argocd_auth.data["password"]
}
