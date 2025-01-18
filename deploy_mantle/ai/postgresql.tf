
resource helm_release  postgres {
  namespace = var.namespace
  name = "ailab"
  repository = local.helm.postgres.repo
  chart = local.helm.postgres.chart

  set {
    name = "metrics.enabled"
    value = true
  }

  #TODO:  enable  tls

}

