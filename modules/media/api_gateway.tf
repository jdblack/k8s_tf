# This media gateway instance: NGF control plane + the `media-private` Gateway,
# running in the media namespace. Dedicated to media apps only -- the controller
# watches only the media namespace (watch_namespaces = [var.namespace]).
#
# The caller (this module) owns the media namespace; the gateway module never
# creates one (depends_on the namespace resource here). The standard Gateway API
# CRDs are cluster-scoped and installed exactly once by
# modules/network/api_gateway_config.tf (core stack) -- apply core before mantle
# on a fresh cluster.
module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  depends_on = [kubernetes_namespace_v1.namespace]
}
