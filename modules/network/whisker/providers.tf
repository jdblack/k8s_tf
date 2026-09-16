terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Calico NetworkPolicy CRs in the `calico-system` tier, see tier.tf.
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
