module "ingress" {
  source = "../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "monitoring-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 3000 }]
  }]
}
