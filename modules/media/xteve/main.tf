resource helm_release xteve {
  name  = "xteve"
  repository = "https://k8s-at-home.com/charts/"
  chart = "xteve"
  namespace = var.namespace
  values = [yamlencode(local.helm_values)]
}


