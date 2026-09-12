terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
    # For the ntfy ServiceMonitor: it is a CR with no typed Terraform resource,
    # and kubernetes_manifest would need the CRD schema at PLAN time -- which the
    # release this module installs is what creates. kubectl_manifest applies raw
    # YAML, so it only needs the CRD at apply time (same reason
    # modules/cert_manager uses it for the ClusterIssuer).
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}
