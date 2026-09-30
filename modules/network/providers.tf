terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
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
