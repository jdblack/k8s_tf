resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  values     = [yamlencode(local.helm_values)]
}


