terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.4.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.4.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }

  backend "kubernetes" {
    namespace     = "kube-system"
    secret_suffix = "core"
    config_path   = "~/.kube/config"
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
