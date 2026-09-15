resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
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

  # Controllers (MetalLB, cloud LBs) like to write annotations on Services.
  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}
