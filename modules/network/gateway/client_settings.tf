# NGF 2.x ignores the legacy nginx.org/client-max-body-size HTTPRoute
# annotation; client request body size is configured via the
# ClientSettingsPolicy API (gateway.nginx.org/v1alpha1). Targetting the Gateway
# removes nginx's 1m client_max_body_size default for EVERY route on this
# gateway (including ListenerSet-derived listeners in other namespaces), so
# apps don't each need their own policy. A more specific route-level
# ClientSettingsPolicy can still override this per app if one ever needs a
# tighter cap.
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
