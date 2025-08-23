# This is the new nginx one
resource helm_release  ingress_internal {
  namespace  = var.namespace
  name       = "ingress-internal"
  repository = "oci://ghcr.io/nginx/charts/"
  chart      = "nginx-ingress"
  depends_on  = [ kubernetes_namespace.namespace]
  set = [ {
    name = "controller.ingressClass.name"
    value = "internal"
  } ]
}
