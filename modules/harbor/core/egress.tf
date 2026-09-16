# Three policies for the chart's seven pods, all on the chart's own labels; the base is DNS + own
# namespace, and Calico unions the two narrow calls into it rather than having them restate it.
module "egress" {
  source = "../../network/firewalls/egress"

  namespace    = var.namespace
  name         = "harbor-egress"
  pod_selector = { "app.kubernetes.io/name" = "harbor" }
}

# The only pod here with an off-cluster dependency: it pulls its own DBs on a rotation, which a flow
# window will not have caught -- a DNS+self rule here would look correct and break the next new scan.
module "egress_trivy" {
  source = "../../network/firewalls/egress"

  namespace      = var.namespace
  name           = "harbor-trivy-egress"
  pod_selector   = { "app.kubernetes.io/component" = "trivy" }
  allow_internet = true
}

# harbor-core speaks OIDC back through the private gateway: `oauth2_server` is the *public* auth
# host, which split-horizon DNS sends to the gateway's data plane, so the peer is that pod on 443 --
# a CIDR for the VIP permitted nothing (post-DNAT). Harbor caches the provider, so a missing peer
# only shows up as broken login once the cache expires, and never in a flow window.
module "egress_core" {
  source = "../../network/firewalls/egress_peer"

  namespace    = var.namespace
  name         = "harbor-core-gateway-egress"
  pod_selector = { "app.kubernetes.io/component" = "core" }

  # NGF's data-plane label, the same one media's data-plane policy selects; tracks var.gateway_name.
  to_peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}
