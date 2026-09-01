

locals {
  helm_values = {
    # Both charts in this module share the helm_values local (Terraform allows
    # a local name to be declared only once per module); each release references
    # its own key.
    longhorn = {
      persistence = {
        defaultDataLocality      = "best-effort"
        defaultClassReplicaCount = 2
      }
      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }
      longhornUI = {
        replicas = 0
      }
    }
    snapshot_controller = {}
  }
}

resource "kubernetes_namespace_v1" "longhorn" {
  metadata {
    name = var.longhorn_namespace
  }
}

resource "helm_release" "longhorn" {
  name          = "longhorn"
  namespace     = var.longhorn_namespace
  repository    = var.helm_longhorn_url
  chart         = var.helm_longhorn_chart
  depends_on    = [kubernetes_namespace_v1.longhorn]
  wait_for_jobs = true
  version       = "1.10.1"
  wait          = true
  values        = [yamlencode(local.helm_values.longhorn)]
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl -n ${self.namespace} patch lhs deleting-confirmation-flag -p '{\"value\": \"true\"}' --type=merge"
  }
}

