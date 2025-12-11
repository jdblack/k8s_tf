

resource kubernetes_persistent_volume volume {
  metadata {
    name = var.name
    labels = {
      juicefs-name = var.name
    }
  }

  spec {
    capacity = {
      storage = "2Pi"
    }
    volume_mode = "Filesystem"
    access_modes = [ "ReadWriteMany" ]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source  {
      csi  {
        driver       = "csi.juicefs.com"
        volume_handle = var.name
        fs_type      = "juicefs"

        node_publish_secret_ref {
          name      = local.secret_name
          namespace = var.metadata_namespace
        }
      }
    }
  }
  depends_on = [kubernetes_secret.secret]

}


resource kubectl_manifest pvc {

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind = "PersistentVolumeClaim"
    metadata = {
      name = var.name
      namespace = var.namespace
    }
    spec = {
      accessModes = [ "ReadWriteMany" ]
      volumeMode = "Filesystem"
      storageClassName = ""
      resources = {
        requests = {
          storage = "2Pi"
        }
      }
      selector = {
        matchLabels = {
          juicefs-name = var.name
        }
      }
    }
  })
}



