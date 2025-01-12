
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
  }
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

