resource "kubernetes_service_v1" "dispatcharr" {
  metadata {
    namespace = var.namespace
    name      = local.svc_name
    labels = {
      "app.kubernetes.io/name" = var.name
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    port {
      name        = "service"
      port        = 9191
      target_port = 9191
    }
  }
}
