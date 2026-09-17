terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # Only for `network/firewalls/egress` (the random_id suffix a call without an explicit name would
    # use; both calls here set one, so nothing is created).
    random = {
      source = "hashicorp/random"
    }
  }
}
