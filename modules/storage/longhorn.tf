locals {
  helm_values = {
    longhorn = {
      defaultSettings = {
        concurrentAutomaticEngineUpgradePerNodeLimit = 3
        upgradeChecker                               = false

        # Never let one node hold two of a volume's three replicas: that node's loss would
        # then take the volume below the 2/3 it needs to stay healthy. Off by default.
        replicaSoftAntiAffinity = "true"

        # Longhorn's replica scheduler is space-based, so it stacks replicas on whichever
        # node currently has the most free bytes (k8smaster here) and never revisits the
        # decision. With data locality best-effort (below) the intent is one replica on the
        # node running the workload and the rest spread across the others; this makes it
        # actually converge on that instead of drifting.
        replicaAutoBalance = "best-effort"

        # Volumes created through the UI/API or longhorn-static bypass the StorageClass
        # below, which is where the Kubernetes path gets its locality.
        defaultDataLocality = "best-effort"
      }
      csi = {
        attacherReplicaCount    = 1
        provisionerReplicaCount = 1
        resizerReplicaCount     = 1
        snapshotterReplicaCount = 1
      }
      persistence = {
        defaultDataLocality      = "best-effort"
        defaultClassReplicaCount = 3
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
