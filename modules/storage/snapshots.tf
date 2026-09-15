locals {
  snapshot_controller = {}
}

resource "helm_release" "snapshot_controller" {
  name       = "snapshot-controller"
  repository = "https://piraeus.io/helm-charts/"
  chart      = "snapshot-controller"
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.snapshot_controller)]
}

# kubectl_manifest (not kubernetes_manifest) on purpose: the CRD
# (snapshot.storage.k8s.io) is installed by the snapshot-controller chart in the
# SAME apply run, and kubernetes_manifest needs it to exist at plan time.
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


