# Namespace profile: DNS + self + the API server + the public internet. Namespace-wide because this
# namespace's real pod list is open-ended -- argo-wf's workflow pods run arbitrary containers and their
# executor patches its own Workflow CR -- and the gain that matters is that nothing here reaches the LAN
# or another namespace's pods, which every pod could before.
module "egress" {
  source = "../../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "argo-egress"

  allow_k8s_api  = true
  allow_internet = true
}

# repo-server's harbor OCI charts (`harbor.<domain>/library`, the corsless and llm-embedder Applications).
module "egress_repo_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-repo-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argocd-repo-server" }

  to_peers = local.gateway_peer
}

# argocd-server's OIDC issuer (`auth.<domain>`) is the same gateway pod, not an authentik pod.
module "egress_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argocd-server" }

  to_peers = local.gateway_peer
}

# argo-wf's server dials the same OIDC issuer; its pods are covered by the floor.
module "egress_wf_server_gateway" {
  source = "../../network/firewalls/egress_peer"

  namespace    = kubernetes_namespace_v1.namespace.metadata[0].name
  name         = "argo-wf-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/name" = "argo-workflows-server" }

  to_peers = local.gateway_peer
}
