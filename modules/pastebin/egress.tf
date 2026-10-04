# Baseline: DNS and this namespace only. The app needs nothing from the internet.
module "egress" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "${var.name}-egress"
}

# Discovery, JWKS and the token exchange all go to authentik, which the private gateway
# serves; the peer is the gateway pod the MetalLB address DNATs to, not the address itself.
module "egress_auth" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "${var.name}-auth-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.auth_gateway_name }
    ports        = [{ port = 443 }]
  }]
}
