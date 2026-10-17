resource "helm_release" "ellmephant" {
  name       = local.release
  namespace  = var.namespace
  repository = var.chart_repository
  chart      = var.chart
  version    = var.chart_version
  wait       = true
  timeout    = 600

  values = [yamlencode(local.helm_values)]
}
