module "ingress" {
  source = "../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "argo-ingress"

  from_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 8080 }, { port = 2746 }]
  }]
}
