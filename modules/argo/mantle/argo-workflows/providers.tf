terraform {
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
