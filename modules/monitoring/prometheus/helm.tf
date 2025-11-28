resource helm_release prometheus {
  name = var.prometheus_name
  namespace = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts" 
  chart = "kube-prometheus-stack"
  values = [yamlencode(local.prometheus)]
}


