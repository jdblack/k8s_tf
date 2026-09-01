variable "namespace" {}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = var.namespace
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  values     = [yamlencode(local.helm_values)]
}
