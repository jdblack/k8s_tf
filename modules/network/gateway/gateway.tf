# The Gateway is generic shared infrastructure: it exposes no app-specific
# HTTPS listeners -- each app module declares its own via a ListenerSet (in the
# app namespace) plus its own HTTPRoute and Certificate.
#
# The CRD (gateway.networking.k8s.io/v1) requires spec.listeners to contain at
# least one entry (MinItems=1), so a minimal :80 HTTP listener is declared but
# NO routes are allowed to attach to it: plain-HTTP requests are dropped (404),
# never redirected or served. HTTPS is the only way in.
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
      # Allow app namespaces to attach ListenerSets (per-app HTTPS listeners).
      allowedListeners = local.allowed_listeners
      listeners = [
        {
          name     = "http"
          port     = 80
          protocol = "HTTP"
          # No routes can ever attach here: the namespace selector matches
          # nothing, so plain-HTTP requests are dropped (404), never redirected.
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
