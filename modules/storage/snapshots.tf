locals {
  snapshot_controller = {}
}

resource "helm_release" "snapshot_controller" {
  name       = "snapshot-controller"
  repository = "https://piraeus.io/helm-charts/"
  chart      = "snapshot-controller"
  namespace  = var.namespace
  values     = [yamlencode(local.snapshot_controller)]
}

# VolumeSnapshotClass CRs are applied via kubectl_manifest (not
# kubernetes_manifest) on purpose: their CRD (snapshot.storage.k8s.io) is
# installed by the snapshot-controller Helm chart in the SAME apply run.
# kubernetes_manifest needs the CRD to exist at plan time, which it does not on
# a fresh cluster; kubectl_manifest plans fine and applies after the chart has
# created the CRDs (depends_on below).
resource "kubectl_manifest" "longhorn_snapshot" {
  yaml_body = yamlencode({
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "longhorn-snapshot"
    }
    parameters = {
      type = "snap"
    }
    driver         = "driver.longhorn.io"
    deletionPolicy = "Delete"
  })

  depends_on = [
    helm_release.snapshot_controller,
    helm_release.longhorn
  ]
}

resource "kubectl_manifest" "longhorn_backup" {
  yaml_body = yamlencode({
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "longhorn-backup"
    }
    driver         = "driver.longhorn.io"
    deletionPolicy = "Delete"
  })

  depends_on = [
    helm_release.snapshot_controller,
    helm_release.longhorn
  ]
}


