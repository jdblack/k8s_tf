resource kubernetes_namespace_v1 storage {
  count = var.create_ns == true ? 1 : 0
  metadata {
    name = var.namespace
  }
}
