resource helm_release argocd {
  name       = var.name
  repository = var.repo
  chart      = var.chart
  namespace  = var.namespace
  upgrade_install = true

  values = [yamlencode(local.config)]
}

