

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
  wait          = true
  set = [
    {
      name  = "persistence.defaultDataLocality"
      value = "best-effort"
    },
    {
      name  = "metrics.serviceMonitor.enabled"
      value = "true"
      }, {
      name  = "persistence.defaultClassReplicaCount"
      value = "2"
      }, {
      name  = "longhornUI.replicas"
      value = "0"
    }
  ]
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl -n ${self.namespace} patch lhs deleting-confirmation-flag -p '{\"value\": \"true\"}' --type=merge"
  }
}

