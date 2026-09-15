variable "namespace" {}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = var.namespace
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
