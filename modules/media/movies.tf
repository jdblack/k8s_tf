resource kubernetes_persistent_volume_claim_v1 torrents {
  metadata {
    name = "torrents"
    namespace = var.namespace
  }
  spec {
    storage_class_name = "seaweedfs-csi"
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "1Pi"
      }
    }
  }
}

resource kubernetes_persistent_volume_claim_v1 movies_archive {
  metadata {
    name = "movies-archive"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = "seaweedfs-csi"
    resources {
      requests = {
        storage = "1Pi"
      }
    }
    selector {
      match_labels = {
        seaweed_id = "movies-archive"
      }
    }
  }
}

resource kubernetes_persistent_volume_v1 movies_archive {
  metadata {
    name = "movies-archive"
    labels = {
      seaweed_id = "movies-archive"
    }
  }
  spec {
    storage_class_name = "seaweedfs-csi"
    capacity = {
      storage = "2Pi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source  {
      csi  {
        driver = "seaweedfs-csi-driver"
        volume_handle = "movies-archive"
      }
    }
  }
}


