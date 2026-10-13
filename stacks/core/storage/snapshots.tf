locals {
  # keepCRDs: chart-owned CRDs are dropped on uninstall, taking every VolumeSnapshot with them.
  snapshot_controller = {
    keepCRDs = true
  }
}

resource "helm_release" "snapshot_controller" {
  name       = "snapshot-controller"
  repository = "https://piraeus.io/helm-charts/"
  chart      = "snapshot-controller"
  version    = var.helm_snapshot_controller_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.snapshot_controller)]
}

# kubectl_manifest, not kubernetes_manifest: this CRD arrives in the same apply.
resource "kubectl_manifest" "longhorn_snapshot" {
  yaml_body = yamlencode({
    apiVersion     = "snapshot.storage.k8s.io/v1"
    kind           = "VolumeSnapshotClass"
    metadata       = { name = "longhorn-snapshot" }
    driver         = "driver.longhorn.io"
    deletionPolicy = "Delete"
    parameters     = { type = "snap" }
  })

  depends_on = [helm_release.snapshot_controller, helm_release.longhorn]
}

resource "kubectl_manifest" "longhorn_backup" {
  yaml_body = yamlencode({
    apiVersion     = "snapshot.storage.k8s.io/v1"
    kind           = "VolumeSnapshotClass"
    metadata       = { name = "longhorn-backup" }
    driver         = "driver.longhorn.io"
    deletionPolicy = "Delete"
  })

  depends_on = [helm_release.snapshot_controller, helm_release.longhorn]
}
