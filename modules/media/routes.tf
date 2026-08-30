
# Redirect all plain-HTTP to HTTPS via the Gateway :80 listener.
# Per-app HTTPRoutes, ListenerSets, and Certificates are declared in each
# app module (sonarr/, radarr/, ...).
resource "kubernetes_manifest" "redirect_http" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "redirect-http"
      namespace = var.namespace
    }
    spec = {
      parentRefs = [{
        name        = var.gateway_name
        namespace   = var.gateway_namespace
        sectionName = "http"
      }]
      hostnames = ["*.${var.domain}"]
      rules = [{
        filters = [{
          type = "RequestRedirect"
          requestRedirect = {
            scheme     = "https"
            statusCode = 301
          }
        }]
      }]
    }
  }
}
