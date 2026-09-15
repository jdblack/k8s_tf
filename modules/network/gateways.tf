# Shared, cluster-wide NGF gateways in var.namespace, open to ListenerSets from any
# namespace. Apps own their exposure from their own namespace (listener_set + HTTPRoute).
#
# Data planes take a MetalLB VIP like every other LoadBalancer (nothing pins them).
# Two addresses are router-coupled and cannot be made DNS-independent, since DNS is
# not in the path of an inbound NAT rule: WAN 443 -> the public gateway, WAN 21010 ->
# the qbittorrent torrent Service. MetalLB keeps an IP for a Service's lifetime, so
# unpinning moves nothing -- but a *recreated* Service gets a new pool IP and the
# router rules need re-pointing (re-pin via the submodule's load_balancer_ip).
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
