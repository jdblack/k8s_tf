# Shared cluster-wide NGF gateways, open to ListenerSets from any namespace; apps own their own
# exposure. Two addresses are router NAT rules DNS cannot cover (WAN 443 -> the public gateway, WAN
# 21010 -> the torrent Service): a *recreated* Service takes a new pool IP and needs re-pointing.
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
