
resource helm_release smartctl {
  name = var.name
  namespace = var.namespace
  repository = "oci://ghcr.io/prometheus-community/charts"
  chart = "prometheus-smartctl-exporter" 
  values = [yamlencode(local.smartctl)]
}

