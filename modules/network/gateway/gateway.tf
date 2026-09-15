# The Gateway takes no app-specific listeners: each app declares its own via a ListenerSet.
#
# The CRD requires spec.listeners >= 1 entry (MinItems=1), so a minimal :80 listener is
# declared with a selector matching no namespace -- plain HTTP is dropped (404), never
# redirected. HTTPS is the only way in.
resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = {
      gatewayClassName = var.name
      allowedListeners = local.allowed_listeners
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          # Selector matches no namespace, so no route can attach here.
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  "kubernetes.io/metadata.name" = "http-requests-drop-here"
                }
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [helm_release.ngf]
}
