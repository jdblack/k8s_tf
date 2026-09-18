terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
