# Static, not dynamic: Kubernetes always names a dynamically provisioned volume pvc-<uid>,
# and the handle below is what names the bucket under the filer (/buckets/ai-models), matching
# the movies-archive/photos pair. Retain, because re-pulling the blobs is 5 GB.
# The claim itself lives with the app that uses it (deployments/ai/ollama.yaml), bound here
# by volumeName.
resource "kubernetes_persistent_volume_v1" "ai_models" {
  metadata {
    name = var.name
    labels = {
      seaweed_id = var.name
    }
  }

  spec {
    storage_class_name = "seaweedfs-csi"
    capacity = {
      storage = var.size
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      csi {
        driver        = "seaweedfs-csi-driver"
        volume_handle = var.name
      }
    }
  }
}
