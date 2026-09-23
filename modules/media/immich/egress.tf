module "egress_auth" {
  source = "../../network/firewalls/egress"

  namespace = var.namespace
  name      = "${var.name}-auth-egress"

  pod_selector = {
    "app.kubernetes.io/instance" = var.name
    "app.kubernetes.io/name"     = "server"
  }

  to_peers = [{
    namespace    = var.auth_gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.auth_gateway_name }
    ports        = [{ port = 443 }]
  }]
}
