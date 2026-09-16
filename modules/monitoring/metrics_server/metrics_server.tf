variable "namespace" {}

# metrics-server chart version.
variable "helm_version" { default = "3.14.0" }

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = var.namespace
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}
