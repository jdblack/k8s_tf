
terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
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


provider "kubectl" {
  config_path = "~/.kube/config"
}



