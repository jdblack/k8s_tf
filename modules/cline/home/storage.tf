# Local scratchpad: fast, node-local, single-writer.
resource "kubernetes_persistent_volume_claim_v1" "scratch" {
  metadata {
    name      = "cline-scratch"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.scratch_storage_class

    resources {
      requests = { storage = var.scratch_size }
    }
  }
}

# The shared volume: ReadWriteMany over seaweedfs, so the pod AND the laptop can mount it at once.
# This is where things worth keeping outlive a single pod.
resource "kubernetes_persistent_volume_claim_v1" "shared" {
  metadata {
    name      = "cline-shared"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.shared_storage_class

    resources {
      requests = { storage = var.shared_size }
    }
  }
}
