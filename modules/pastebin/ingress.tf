module "ingress" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "${var.name}-ingress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.port }]
  }]
}
