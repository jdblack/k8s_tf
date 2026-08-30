resource "kubernetes_service_v1" "service" {
  metadata {
    namespace = var.namespace
    name      = var.name
    labels = {
      "app.kubernetes.io/name" = var.name
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    port {
      name        = "webui"
      port        = var.web_port
      target_port = var.web_port
    }
    port {
      name        = "torrent"
      port        = var.torrent_port
      target_port = var.torrent_port
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}
