resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "postgres"
      port        = var.port
      target_port = "postgres"
    }
  }
}
