
resource "helm_release" "argocd" {
  name            = var.name
  repository      = var.repo
  chart           = var.chart
  version         = var.helm_version
  namespace       = var.namespace
  upgrade_install = true
  wait            = true
  timeout         = 600

  values = [yamlencode(local.helm_values)]
}

