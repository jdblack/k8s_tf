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
    # externalTrafficPolicy=Local so the torrent LoadBalancer keeps working
    # under the media ingress firewall: Local preserves the peer's real source
    # IP (LAN or internet) and routes the VIP only to the node running the
    # pod. The default (Cluster) SNATs cross-node traffic to a cluster-internal
    # IP that allowed_ingress_cidrs cannot match, which the firewall drops.
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    # BitTorrent uses the SAME port for TCP (peer connections) and UDP (uTP,
    # DHT, UDP trackers). The Service must list BOTH protocols: without a UDP
    # port kube-proxy has no UDP DNAT for the LB VIP, so inbound UDP is dropped
    # at the node even though the app listens on UDP 21010. (Verified: with TCP
    # only, an external TCP probe reached the pod and a UDP probe did not.)
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
      metadata[0].annotations
    ]
  }

  depends_on = [kubernetes_service_v1.service]
}
