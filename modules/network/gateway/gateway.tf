# The Gateway is generic shared infrastructure: it exposes NO app-specific
# listeners. Each app module declares its own HTTPS listener via a
# ListenerSet (in the app namespace) plus its own HTTPRoute and Certificate.
# Only the shared :80 HTTP listener (-> https redirect) lives here.
resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = var.namespace
    }
    spec = {
      gatewayClassName = var.gateway_class
      # Allow app namespaces to attach ListenerSets (per-app HTTPS listeners).
      allowedListeners = local.allowed_listeners
      listeners = [
        {
          name          = "http"
          port          = 80
          protocol      = "HTTP"
          hostname      = "*.${var.domain}"
          allowedRoutes = local.allowed_routes
        }
      ]
    }
  })

  depends_on = [helm_release.ngf]
}
