
resource kubernetes_namespace storage {
  metadata {
    name = var.namespace
  }
}
