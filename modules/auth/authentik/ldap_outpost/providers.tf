terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
