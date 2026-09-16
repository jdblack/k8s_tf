# This module's own NGF control plane + the `media-private` Gateway, watching only the media
# namespace. The Gateway API CRDs are cluster-scoped and installed once by core, so apply core before
# mantle on a fresh cluster.
module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  depends_on = [kubernetes_namespace_v1.namespace]
}
