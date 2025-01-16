variable namespace { }

locals {
  metric_server_config  = {
    args = [
    ]
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace = var.namespace
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  set_list {
    name = "args"
    value = [ "--kubelet-insecure-tls" ]
  }

}

