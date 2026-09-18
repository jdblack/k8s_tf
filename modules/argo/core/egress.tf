module "egress" {
  source = "../../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "argo-egress"

  allow_k8s_api  = true
  allow_internet = true
}

module "egress_repo_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-repo-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argocd-repo-server" }

  to_peers = local.gateway_peer
}

module "egress_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argocd-server" }

  to_peers = local.gateway_peer
}

module "egress_wf_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-wf-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argo-workflows-server" }

  to_peers = local.gateway_peer
}
