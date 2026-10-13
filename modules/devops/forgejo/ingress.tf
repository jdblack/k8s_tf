module "ingress" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "${var.name}-ingress"

  # Ports are the container's own (post-DNAT), so SSH is the rootless image's listener, not the
  # VIP's 22 the clients dial.
  peers = [
    {
      # Web: the private gateway terminates TLS and forwards HTTP to us.
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = [{ port = var.port }]
    },
    {
      # VPN clients are SNAT'd to the wireguard pod, so the pod -- not the tunnel subnet -- is
      # the peer. Identity-based, so it survives the pod moving nodes.
      namespace    = var.vpn_namespace
      pod_selector = { "app" = "wireguard" }
      ports        = [{ port = var.port }, { port = var.ssh_listen_port }]
    },
  ]

  # Scraping is not a peer: the ingress baseline admits Prometheus on all ports
  # (allow_scrape), so the /metrics scrape needs no rule here.

  ingress_cidrs = [{
    cidr  = var.host_network
    ports = [{ port = var.ssh_listen_port }]
  }]
}
