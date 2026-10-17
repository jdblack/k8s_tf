terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # The Velero Schedule is a CRD installed by `core`, so it may not exist at plan time — which is
    # why `storage/backup/schedule` uses `kubectl_manifest`. Same provider source the house pins.
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}
