# The outbound half of ingress.tf: a namespace-wide floor with the holes named after it. Measured
# (Whisker, `source_namespaces=kube-auth`, 2026-09-17), that surface is DNS + postgres `:5432` for
# everyone, plus one dial each for the two pods that leave -- the worker's API probe and the server's
# embedded outpost. Nothing here reaches the internet, and locals.tf already killed the version check.
module "egress" {
  source = "../../../network/firewalls/egress"

  namespace = var.namespace
  name      = "authentik-egress"
}

# The worker's grant: `authentik-kube-auth` bakes `customresourcedefinitions [list]` into SA
# `authentik`, which only the worker mounts -- the server's `serviceAccountName` is unset.
module "egress_worker" {
  source = "../../../network/firewalls/egress"

  namespace     = var.namespace
  name          = "authentik-worker-egress"
  pod_selector  = { "app.kubernetes.io/component" = "worker" }
  allow_k8s_api = true
}

# The embedded outpost lives in the server pod only, and points at `auth.<domain>`, which split-horizon
# DNS answers with the private gateway's VIP -- so the peer is that gateway's pod, never the VIP.
module "egress_server_gateway" {
  source = "../../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "authentik-server-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "server" }

  # NGF's data-plane label, the same peer ingress.tf admits as a guest; tracks var.gateway_name.
  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
