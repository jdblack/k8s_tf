
resource helm_release  ingress_internal {
  namespace  = var.namespace
  name       = local.private_ingress_name
  repository = "oci://ghcr.io/nginx/charts/"
  chart      = "nginx-ingress"
  values = [ yamlencode({
    controller = {
      ingressClass = {
        name = local.private_ingress_name
      }
    }
  })]
}

