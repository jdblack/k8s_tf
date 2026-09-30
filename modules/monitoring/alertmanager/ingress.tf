# monitoring-ingress only opens 3000 to the gateway, so the outpost needs its own rule.
module "ingress_outpost" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace    = var.namespace
  name         = "authentik-outpost-ingress"
  pod_selector = { "app.kubernetes.io/name" = "authentik-outpost" }

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = var.http_port }]
  }]
}
