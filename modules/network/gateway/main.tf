resource "helm_release" "ngf" {
  name       = var.release_name
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = var.helm_version
  namespace  = var.namespace

  wait    = true
  timeout = 600
  values  = [yamlencode(local.helm_values)]
}
