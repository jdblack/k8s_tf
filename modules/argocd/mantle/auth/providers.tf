terraform {
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
    }
    authentik = {
      source = "goauthentik/authentik"
    }
  }
}
