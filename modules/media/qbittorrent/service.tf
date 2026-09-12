# Web UI Service (ClusterIP). The media gateway -> authentik outpost -> here,
# and the *arr apps use it as their download client (`qbittorrent:8080`).
# Deliberately ClusterIP (not LoadBalancer): the UI must only be reachable
# through the outpost, so it has no LoadBalancer IP that would let LAN clients
# bypass authentik.
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
  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

# Torrent Service (LoadBalancer). Peer traffic only -- never behind the
# authentik outpost (bittorrent peers can't log in). Pinned to
# var.torrent_lb_ip because the home router port-forwards 21010 to that
# address, so splitting the old combined Service must not reassign it.
# depends_on so the web UI Service releases its IP before this one is created.
resource "kubernetes_service_v1" "torrent" {
  metadata {
    namespace = var.namespace
    name      = "${var.name}-torrent"
    labels = {
      "app.kubernetes.io/name" = var.name
    }
  }

  spec {
    type             = "LoadBalancer"
    load_balancer_ip = var.torrent_lb_ip

    selector = {
      "app.kubernetes.io/name" = var.name
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

  depends_on = [kubernetes_service_v1.service]
}
