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
      source = "goauthentik/authentik"
      # Tracks the app: bumped with the 2026.8.2 chart in `core`, whose API this provider is generated
      # from (the 2025.10 API renamed user `uuid` -> `uid` and made `expires`/`expiring` required).
      version = "2026.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
    # Route53 for the vaultwarden A record only: one record in one zone, via the least-privilege
    # lg-route53 key in var.deployment.cert.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # OIDC signing keypairs, generated per provider in modules/auth/authentik/oidc_provider.
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

# Credentials come from tfvars, not the ambient environment: the shell's default AWS identity is a
# different, broader principal. NOTE the v6 rename -- `secret_key`, not the v5-era
# `secret_access_key`; the tfvars key keeps its historical AWS_SECRET_ACCESS_KEY name (cert-manager's
# DNS-01 solver Secret reads it).
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
  # Full FQDN so the gateway's ListenerSet TLS SNI matches.
  server_addr = "${var.deployment.argocd_devops.server}.${var.deployment.common.domain}:443"
  username    = "admin"
  password    = data.kubernetes_secret_v1.argocd_auth.data["password"]
}