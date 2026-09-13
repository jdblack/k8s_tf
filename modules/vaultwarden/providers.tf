terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # The Longhorn RecurringJob (backup.tf) is a CR: kubernetes_manifest would
    # need longhorn.io's CRD at plan time, kubectl_manifest doesn't.
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
