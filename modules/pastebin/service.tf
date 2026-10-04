resource "kubernetes_service_v1" "service" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = local.labels
  }

  spec {
    type = "ClusterIP"

    selector = local.labels

    port {
      name        = "http"
      port        = var.port
      target_port = "http"
    }
  }
}
