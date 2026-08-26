
resource helm_release helm {
  name  = var.name
  repository = var.helm_repo
  chart = var.chart
  version = "3.6.1"
  namespace = var.namespace
  values = [yamlencode(local.helm_values)]
}

