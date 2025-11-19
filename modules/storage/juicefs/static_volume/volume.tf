locals {
  secret_name = "juicefs-${var.name}"
}

resource kubernetes_secret secret {
  metadata {
    name      = local.secret_name
    namespace = var.namespace
    labels = {
      "juicefs.com/validate-secret" = "true"
    }
  }

  data = {
    name        = var.name
    metaurl     = "redis://${local.db_name}.${var.namespace}"
    storage     = "s3"
    bucket      = var.bucket_url
    access-key  = var.access_key
    secret-key  = var.secret_key
  }
}


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
          namespace = var.namespace
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



