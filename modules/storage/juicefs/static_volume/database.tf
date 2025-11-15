
locals {
  fqdn = "${var.name}.${var.domain}"
  config = {
    persistence = {
      size = "1Gi"
    }
  }
}

resource "helm_release" "valkey" {
  name       = "valkey-${var.name}"
  repository = "https://cloudpirates.io/helm-charts"
  chart      = "valkey"
  namespace  = var.namespace

  values = [yamlencode(local.config)]
}

