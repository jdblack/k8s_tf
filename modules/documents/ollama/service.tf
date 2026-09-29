resource "kubernetes_service_v1" "ollama" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "http"
      port        = var.port
      target_port = "http"
    }
  }
}
