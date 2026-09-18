resource "helm_release" "prometheus" {
  name       = var.prometheus_name
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]

  depends_on = [
    kubernetes_secret_v1.grafana_oidc,
  ]
}
