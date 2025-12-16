module movies {
  count = 0
  name = var.movies_name
  source = "../storage/juicefs/static_volume/"
  namespace = var.namespace
  bucket_url = local.bucket_url
  metadata_namespace = "media"
  access_key = var.s3["access_key"]
  secret_key = var.s3["secret_key"]
}


resource kubernetes_persistent_volume_claim torrents {
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

resource kubernetes_persistent_volume_claim movies_archive {
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

resource kubernetes_persistent_volume movies_archive {
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


