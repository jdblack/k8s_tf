resource kubernetes_persistent_volume_claim_v1 samba {
  metadata {
    name      = local.samba_name
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "seaweedfs-csi"
    resources {
      requests = {
        storage = "1Pi"
      }
    }
    volume_name = kubernetes_persistent_volume_v1.samba.metadata[0].name
  }
}

resource kubernetes_persistent_volume_v1 samba {
  metadata {
    name = local.pv_name
    labels = {
      seaweed_id = local.pv_name
    }
  }
  spec {
    storage_class_name = "seaweedfs-csi"
    capacity = {
      storage = "1Pi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver        = "seaweedfs-csi-driver"
        volume_handle = local.pv_name
      }
    }
  }
}
