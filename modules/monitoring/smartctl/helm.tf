
resource "helm_release" "smartctl" {
  name       = var.name
  namespace  = var.namespace
  repository = "oci://ghcr.io/prometheus-community/charts"
  chart      = "prometheus-smartctl-exporter"
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}

