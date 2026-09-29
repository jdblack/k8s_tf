resource "kubernetes_service_v1" "valkey" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "valkey"
      port        = var.port
      target_port = "valkey"
    }
  }
}
