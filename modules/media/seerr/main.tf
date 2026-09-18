resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  version    = var.helm_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
