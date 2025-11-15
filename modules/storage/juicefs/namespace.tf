resource kubernetes_namespace storage {
  count = var.create_ns == true ? 1 : 0
  metadata {
    name = var.namespace
  }
}
