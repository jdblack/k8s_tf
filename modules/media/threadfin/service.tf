resource "kubernetes_service_v1" "service" {
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
      port        = var.service_port
      target_port = var.service_port
    }
  }
}
