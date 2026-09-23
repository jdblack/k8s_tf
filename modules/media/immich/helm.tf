resource "helm_release" "helm" {
  name       = var.name
  repository = "oci://ghcr.io/immich-app/immich-charts"
  chart      = "immich"
  version    = var.helm_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
