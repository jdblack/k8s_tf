locals {
	snapshot_controller = {
	}
}

resource helm_release snapshot_controller {
	name  = "snapshot-controller"
	repository = "https://piraeus.io/helm-charts/"
	chart = "snapshot-controller"
	namespace = var.namespace
	values = [yamlencode(local.snapshot_controller)]
}

resource kubernetes_manifest longhorn_snapshot {
  manifest = {
    kind       = "VolumeSnapshotClass"
    apiVersion = "snapshot.storage.k8s.io/v1"
    metadata = {
      name      = "longhorn-snapshot"
    }
    parameters = {
      type = "snap"
    }
    driver = "driver.longhorn.io"
    deletionPolicy = "Delete"
  }

    depends_on = [
      helm_release.snapshot_controller,
      helm_release.longhorn
    ]
}

resource kubernetes_manifest longhorn_backup {
  manifest = {
    kind       = "VolumeSnapshotClass"
    apiVersion = "snapshot.storage.k8s.io/v1"
    metadata = {
      name      = "longhorn-backup"
    }
    driver = "driver.longhorn.io"
    deletionPolicy = "Delete"
  }

  depends_on = [
    helm_release.snapshot_controller,
    helm_release.longhorn
  ]
}


