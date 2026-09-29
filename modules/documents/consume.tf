# The inbox: files sit here only until a worker picks them up, which is why it is small and
# not backed up.
resource "kubernetes_persistent_volume_claim_v1" "consume" {
  metadata {
    name      = local.consume_pvc
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.consume_size
      }
    }
  }
}
