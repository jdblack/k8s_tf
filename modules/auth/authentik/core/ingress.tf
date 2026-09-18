module "ingress" {
  source = "../../../network/firewalls/ingress"

  namespace = var.namespace
  name      = "authentik-ingress"

  from_peers = concat(
    [{
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = local.server_ports
    }],
    [for ns in var.outpost_namespaces : {
      namespace    = ns
      pod_selector = local.outpost_selector
      ports        = local.server_ports
    }],
  )
}
