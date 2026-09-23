resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = local.postgres_name
    namespace = var.namespace
    labels    = local.postgres_labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.postgres_labels

    port {
      name        = "postgres"
      port        = local.postgres_port
      target_port = "postgres"
    }
  }
}
