terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    keycloak = {
      source = "mrparkers/keycloak"
      version = "4.1.0"
    }
    helm = {
      version = "~> 2.8"
    }
    kubernetes = {
      version = "~> 2.17"
    }
  }
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

