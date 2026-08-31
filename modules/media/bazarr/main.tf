
resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  version    = "2.3.0"
  chart      = var.chart
  namespace  = var.namespace
  values     = [yamlencode(local.helm_values)]
}

