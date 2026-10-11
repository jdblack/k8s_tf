# The connector spawns whatever MCP servers TypingMind hands it and talks to remote servers
# itself, so it needs the internet -- which `allow_internet` grants as 0.0.0.0/0 minus RFC1918,
# leaving the LAN unreachable from a pod that runs commands chosen elsewhere.
module "egress_internet" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace      = var.namespace
  name           = "${var.name}-internet-egress"
  pod_selector   = local.labels
  allow_internet = true

  # TypingMind is configured with the apps' hostnames, so the connector reaches them through a
  # Gateway on the LAN. kube-proxy DNATs the VIP to the data-plane pod before egress policy runs,
  # so the peer is that pod, not the VIP address -- which also keeps it correct across reassignment.
  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
