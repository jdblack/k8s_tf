module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  depends_on = [kubernetes_namespace_v1.namespace]
}
