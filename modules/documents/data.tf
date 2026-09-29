# sqlite, the search index and the classifier: the module's only backup target.
resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = local.data_pvc
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.data_size
      }
    }
  }
}
