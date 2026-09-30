module "egress" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-egress"
  pod_selector = local.argocd_selector

  allow_k8s_api  = true
  allow_internet = true
}

module "egress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-gateway-egress"
  pod_selector = local.argocd_selector

  peers = local.gateway_peer
}
