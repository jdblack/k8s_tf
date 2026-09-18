terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
