
resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  version    = var.helm_version
  chart      = var.chart
  namespace  = var.namespace
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}

