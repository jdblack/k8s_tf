resource "kubernetes_service_v1" "service" {
  metadata {
    namespace = var.namespace
    name      = var.name
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
      name        = "webui"
      port        = var.web_port
      target_port = var.web_port
    }
  }
}

resource "kubernetes_service_v1" "torrent" {
  metadata {
    namespace = var.namespace
    name      = "${var.name}-torrent"
    labels = {
      "app.kubernetes.io/name" = var.name
    }
  }

  spec {
    type                    = "LoadBalancer"
    load_balancer_ip        = var.torrent_lb_ip
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    port {
      name        = "torrent"
      port        = var.torrent_port
      target_port = var.torrent_port
      protocol    = "TCP"
    }
    port {
      name        = "torrent-udp"
      port        = var.torrent_port
      target_port = var.torrent_port
      protocol    = "UDP"
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations["metallb.io/ip-allocated-from-pool"],
    ]
  }

  depends_on = [kubernetes_service_v1.service]
}
