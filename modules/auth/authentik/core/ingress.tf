module "ingress" {
  source    = "../../../network/firewalls/policy"
  direction = "ingress"

  namespace = var.namespace
  name      = "authentik-ingress"

  peers = concat(
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
    # No pod selector on the source: the port is what scopes this to the outpost, since
    # nothing else in this namespace listens there.
    [for ns in var.ldap_client_namespaces : {
      namespace = ns
      ports     = [for port in var.ldap_ports : { port = port }]
    }],
  )
}
