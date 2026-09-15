# Shared, cluster-wide NGF gateways in var.namespace, open to ListenerSets from any
# namespace and watching all namespaces. Apps own their exposure from their own
# namespace via the listener_set submodule + an HTTPRoute.
#
# Data-plane Services take a MetalLB VIP like every other LoadBalancer here (no
# load_balancer_ip passed). Two addresses are router-coupled and cannot be made
# DNS-independent, since DNS is not in the path of an inbound NAT rule: the router
# forwards WAN 443 -> the public gateway and WAN 21010 -> the qbittorrent torrent
# Service. MetalLB keeps a Service's IP for that Service's lifetime, so unpinning
# moves nothing -- but a *recreated* Service gets a new pool IP and the router
# rules need re-pointing (re-pin via the submodule's load_balancer_ip).
module "gateway_public" {
  source           = "./gateway"
  namespace        = var.namespace
  name             = "public"
  release_name     = "ngf-public"
  routes_namespace = null
  watch_namespaces = []

  depends_on = [kubernetes_namespace_v1.namespace]
}

module "gateway_private" {
  source           = "./gateway"
  namespace        = var.namespace
  name             = "private"
  release_name     = "ngf-private"
  routes_namespace = null
  watch_namespaces = []

  depends_on = [kubernetes_namespace_v1.namespace]
}
