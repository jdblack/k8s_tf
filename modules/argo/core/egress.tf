module "egress" {
  source = "../../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "argo-egress"

  allow_k8s_api  = true
  allow_internet = true
}

module "egress_gateway" {
  source = "../../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "argo-gateway-egress"

  to_peers = local.gateway_peer
}
