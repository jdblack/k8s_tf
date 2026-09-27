resource "kubernetes_persistent_volume_claim_v1" "photos" {
  metadata {
    name      = "photos"
    namespace = var.namespace
    labels = {
      # Only immich mounts this; excluded so a schedule added later cannot capture the library.
      "velero.io/exclude-from-backup" = "true"
    }
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "seaweedfs-csi"
    resources {
      requests = {
        storage = "1Pi"
      }
    }
    selector {
      match_labels = {
        seaweed_id = "photos"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "photos" {
  metadata {
    name = "photos"
    labels = {
      seaweed_id = "photos"
    }
  }
  spec {
    storage_class_name = "seaweedfs-csi"
    capacity = {
      storage = "2Pi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver        = "seaweedfs-csi-driver"
        volume_handle = "photos"
      }
    }
  }
}
