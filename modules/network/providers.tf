terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    external = {
      source = "hashicorp/external"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
