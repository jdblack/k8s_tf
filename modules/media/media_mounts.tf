

resource kubernetes_secret  s3_key {
  type = "Opaque"
  metadata {
    namespace = var.namespace
    name = "s3-auth-${var.movies_name}"
  }

  data = {
    endpoint = var.media_s3_auth.endpoint
    secretAccessKey = var.media_s3_auth.secret_access_key
    accessKeyID = var.media_s3_auth.access_key_id
  }
}

resource kubernetes_persistent_volume movies {
  metadata {
    name = "${var.namespace}-${var.movies_name}"
  }
  spec {
    access_modes = [ var.media_s3_auth.access_mode ]
    capacity = { storage = var.media_s3_auth.storage_size }
    storage_class_name = "csi-s3"
    claim_ref {
      name = var.movies_name
      namespace = var.namespace
    }
    persistent_volume_source {
      csi {
        driver = "ru.yandex.s3.csi"
        controller_publish_secret_ref {
          name = kubernetes_secret.s3_key.metadata[0].name

          namespace = var.namespace
        }
        node_publish_secret_ref {
          name = kubernetes_secret.s3_key.metadata[0].name
          namespace = var.namespace
        }
        node_stage_secret_ref {
          name = kubernetes_secret.s3_key.metadata[0].name
          namespace = var.namespace
        }
        volume_attributes = {
          capacity = var.media_s3_auth.storage_size
          mounter = var.media_s3_auth.mounter
        }
        volume_handle = var.media_s3_auth.bucket
      }
    }
  }
}

resource kubernetes_persistent_volume_claim movies {
  metadata {
    name = var.movies_name
    namespace = var.namespace
  }
  spec {
    storage_class_name = "csi-s3"
    access_modes = [ var.media_s3_auth.access_mode ]
    resources {
      requests = {
        storage = var.media_s3_auth.storage_size 
      }
    }
    volume_name = kubernetes_persistent_volume.movies.metadata.0.name
  }
}

