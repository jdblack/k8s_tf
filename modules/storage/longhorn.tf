locals {
  helm_values = {
    longhorn = {
      defaultSettings = {
        concurrentAutomaticEngineUpgradePerNodeLimit = 3
        # The manager polls longhorn.io for new releases; nothing here upgrades a release,
        # so the check stays off.
        upgradeChecker = false
      }
      csi = {
        attacherReplicaCount    = 1
        provisionerReplicaCount = 1
        resizerReplicaCount     = 1
        snapshotterReplicaCount = 1
      }
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
  version       = var.helm_longhorn_version
  wait          = true
  timeout       = 600
  values        = [yamlencode(local.helm_values.longhorn)]
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl -n ${self.namespace} patch lhs deleting-confirmation-flag -p '{\"value\": \"true\"}' --type=merge"
  }
}

