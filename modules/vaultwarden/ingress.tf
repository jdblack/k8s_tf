# One guest: the private gateway's data plane on the pod's own :80 (`var.port` -- Rocket and the
# websocket ride the same port, and the HTTPRoute names the Service's :80, so the pod's :80 is what
# DNAT produces). Measured 2026-09-17 over 7d: gateway -> vaultwarden:80 and nothing else. There is no
# second door to write down -- every Service here is ClusterIP, so clients cannot bypass the gateway,
# and /admin is disabled rather than SSO'd (listener.tf), which is why no outpost appears.
module "ingress" {
  source = "../network/firewalls/ingress"

  namespace = var.namespace
  name      = "vaultwarden-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.port }]
  }]
}
