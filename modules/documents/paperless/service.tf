resource "kubernetes_service_v1" "this" {
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

    dynamic "port" {
      for_each = var.flower_enabled ? [1] : []

      content {
        name        = "flower"
        port        = var.flower_port
        target_port = "flower"
      }
    }
  }
}
