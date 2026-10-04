# The browser loads the editors straight from here, so the gateway has to reach the
# document server. oCIS also reads /hosting/discovery through this same listener.
module "ingress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "${var.name}-gateway-ingress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.port }]
  }]
}
