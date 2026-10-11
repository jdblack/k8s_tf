resource "kubectl_manifest" "client_settings" {
  yaml_body = yamlencode({
    apiVersion = "gateway.nginx.org/v1alpha1"
    kind       = "ClientSettingsPolicy"
    metadata = {
      name      = "${var.name}-client-settings"
      namespace = var.namespace
    }
    spec = merge(
      {
        targetRef = {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = var.name
        }
        body = {
          maxSize = var.client_max_body_size
        }
      },
      # Pooled client connections die at nginx's 75s keepalive default; a client that pauses longer
      # then reuses the socket gets a reset. null keeps the nginx default.
      var.client_keepalive_timeout != null ? {
        keepAlive = {
          timeout = {
            server = var.client_keepalive_timeout
          }
        }
      } : {}
    )
  })

  depends_on = [helm_release.ngf]
}
