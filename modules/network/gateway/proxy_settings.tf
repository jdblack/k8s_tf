resource "kubectl_manifest" "proxy_settings" {
  count = var.proxy_timeout != null ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "ProxySettingsPolicy"
    metadata = {
      name      = "${var.name}-proxy-settings"
      namespace = var.namespace
    }
    spec = {
      targetRefs = [{
        group = "gateway.networking.k8s.io"
        kind  = "Gateway"
        name  = var.name
      }]
      timeout = var.proxy_timeout
    }
  })

  depends_on = [helm_release.ngf]
}
