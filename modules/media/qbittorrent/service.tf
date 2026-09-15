# Web UI Service (ClusterIP): gateway -> authentik outpost -> here, and the arr apps
# use it as their download client (`qbittorrent:8080`). Deliberately ClusterIP, so
# no LoadBalancer IP lets LAN clients bypass authentik.
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

# Torrent Service (LoadBalancer), peer traffic only -- never behind the authentik
# outpost (bittorrent peers can't log in).
#
# The VIP floats (var.torrent_lb_ip is null) and DNS cannot compensate: the router
# forwards WAN 21010 to this address and no name resolution is in the path of an
# inbound NAT rule. MetalLB keeps an IP for the Service's lifetime, so floating
# changes nothing today; a re-created Service gets a new pool IP and the router rule
# must be re-pointed (or set qbittorrent_torrent_lb_ip to pin it).
#
# depends_on so the web UI Service gives up the IP first.
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
    # externalTrafficPolicy=Local or the torrent LB breaks under the media ingress
    # firewall: Local preserves the peer's real source IP, whereas the default
    # (Cluster) SNATs cross-node traffic to a cluster-internal IP that
    # allowed_ingress_cidrs cannot match.
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    # BitTorrent uses the SAME port for TCP (peers) and UDP (uTP, DHT, UDP
    # trackers). Both must be listed: with no UDP port kube-proxy has no UDP DNAT
    # for the LB VIP, so inbound UDP is dropped at the node.
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
