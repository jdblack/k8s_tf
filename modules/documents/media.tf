resource "kubernetes_persistent_volume_claim_v1" "media" {
  metadata {
    name      = local.media_pvc
    namespace = kubernetes_namespace_v1.this.metadata[0].name

    labels = {
      # The s3sync is this library's off-site copy; a schedule added later must not capture it.
      "velero.io/exclude-from-backup" = "true"
    }
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.bulk_storage_class

    resources {
      requests = {
        storage = var.media_size
      }
    }

    selector {
      match_labels = {
        seaweed_id = local.media_pvc
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "media" {
  metadata {
    name = local.media_pvc

    labels = {
      seaweed_id = local.media_pvc
    }
  }

  spec {
    storage_class_name = var.bulk_storage_class
    capacity = {
      storage = var.media_pv_size
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver        = "seaweedfs-csi-driver"
        volume_handle = local.media_pvc
      }
    }
  }
}
