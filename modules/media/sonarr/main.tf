
resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace
  version    = "2.2.2"
  values     = [yamlencode(local.helm_values)]
}

