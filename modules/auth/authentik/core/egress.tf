module "egress" {
  source = "../../../network/firewalls/egress"

  namespace = var.namespace
  name      = "authentik-egress"
}

module "egress_worker" {
  source = "../../../network/firewalls/egress"

  namespace     = var.namespace
  name          = "authentik-worker-egress"
  pod_selector  = { "app.kubernetes.io/component" = "worker" }
  allow_k8s_api = true
}

module "egress_server_gateway" {
  source = "../../../network/firewalls/egress"

  namespace    = var.namespace
  name         = "authentik-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "server" }

  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
