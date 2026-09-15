# This module's own NGF control plane + the `media-private` Gateway, watching only
# the media namespace. The Gateway API CRDs are cluster-scoped and installed
# exactly once by modules/network/api_gateway_config.tf (core stack), so on a fresh
# cluster apply core before mantle.
module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  depends_on = [kubernetes_namespace_v1.namespace]
}
