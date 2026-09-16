terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    # Generates the per-provider OIDC signing key in auth.tf.
    tls = {
      source = "hashicorp/tls"
    }
  }
}