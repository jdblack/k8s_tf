module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = "documents-baseline-egress"

  # apt for the tesseract pack on every start, the model pulls, and update checks.
  allow_internet = true
}

module "egress_gateway" {
  source = "../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = "documents-gateway-egress"

  # OIDC discovery and token exchange go out to auth.<domain> and come back through the gateway,
  # which is a LAN address and therefore outside allow_internet.
  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
