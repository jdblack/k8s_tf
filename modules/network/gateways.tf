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
