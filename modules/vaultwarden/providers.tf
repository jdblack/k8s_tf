terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}
