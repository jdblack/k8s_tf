
resource helm_release helm {
  name  = var.name
  repository = var.helm_repo
  chart = var.chart
  namespace = var.namespace
  version = "0.2.35"
  values = [yamlencode(local.helm_values)]
}

