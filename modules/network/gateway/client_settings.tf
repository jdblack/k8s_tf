# NGF 2.x ignores the legacy nginx.org/client-max-body-size annotation: body size comes from
# ClientSettingsPolicy. Targeted at the Gateway rather than a route, so one policy overrides nginx's
# 1m default for every route on this gateway, listeners from other namespaces' ListenerSets included.
resource "kubectl_manifest" "client_settings" {
  yaml_body = yamlencode({
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "ClientSettingsPolicy"
    metadata = {
      name      = "${var.name}-client-settings"
      namespace = var.namespace
    }
    spec = {
      targetRef = {
        group = "gateway.networking.k8s.io"
        kind  = "Gateway"
        name  = var.name
      }
      body = {
        maxSize = var.client_max_body_size
      }
    }
  })

  depends_on = [helm_release.ngf]
}
