terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
