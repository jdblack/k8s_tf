module "gateway" {
  source           = "../network/gateway"
  namespace        = var.namespace
  name             = "media-private"
  helm_version     = var.helm_ngf_version
  routes_namespace = var.namespace
  watch_namespaces = [var.namespace]

  # nginx's 60s read default severs idle websockets (arr UI "connection lost" after a tab switch).
  proxy_timeout = { read = "1h" }

  depends_on = [kubernetes_namespace_v1.namespace]
}
