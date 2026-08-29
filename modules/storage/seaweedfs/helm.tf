
resource helm_release helm {
  name  = var.name
  repository = var.helm_repo
  chart = var.chart
  namespace = var.namespace
  version = var.helm_version
  values = [yamlencode(local.helm_values)]
}

