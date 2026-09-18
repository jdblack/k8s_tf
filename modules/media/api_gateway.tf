module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  helm_version     = var.helm_ngf_version
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  depends_on = [kubernetes_namespace_v1.namespace]
}
