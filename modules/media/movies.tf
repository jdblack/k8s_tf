resource "kubernetes_persistent_volume_claim_v1" "movies_archive" {
  metadata {
    name      = "movies-archive"
    namespace = var.namespace
    labels = {
      # Every media pod mounts this; without it one target's backup captures all of them.
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
        seaweed_id = "movies-archive"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "movies_archive" {
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
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      csi {
        driver        = "seaweedfs-csi-driver"
        volume_handle = "movies-archive"
        volume_attributes = {
          # Node-local, on-disk read cache for the FUSE mount (a mount-time knob;
          # the driver default of 0 leaves it off). 5 GiB caps the local chunk
          # cache on every node that stages movies-archive -- a repeat-read win
          # for Plex and the *arr apps alike, since they share this one volume.
          cacheCapacityMB = "5120"
        }
      }
    }
  }
}
