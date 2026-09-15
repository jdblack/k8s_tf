# Web UI (ClusterIP on purpose: no LoadBalancer IP may bypass the outpost).
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

# Torrent Service (LoadBalancer), peer traffic only -- never behind the outpost.
#
# The VIP floats and DNS cannot help: the router NATs WAN 21010 straight to this address.
# A *recreated* Service gets a new pool IP and the NAT rule must be re-pointed (or pin it
# with torrent_lb_ip). depends_on so the web UI Service gives up the IP first.
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
    # Local, or the LB breaks under the media ingress firewall: Cluster SNATs cross-node
    # traffic to an IP allowed_ingress_cidrs cannot match.
    external_traffic_policy = "Local"

    selector = {
      "app.kubernetes.io/name" = var.name
    }

    # Same port for TCP (peers) and UDP (uTP/DHT/trackers): with no UDP port kube-proxy
    # installs no UDP DNAT and inbound UDP is dropped at the node.
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
