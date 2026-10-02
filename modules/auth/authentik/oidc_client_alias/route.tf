# Attaches to the same listener as authentik's own route, but on the two endpoint paths only.
# Gateway API resolves the most specific match, so these paths reach the proxy while everything
# else still reaches the authentik server directly.
resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "ListenerSet"
        name        = var.listener_name
        namespace   = var.namespace
        sectionName = var.listener_name
      }]
      rules = [{
        matches = [for path in var.paths : {
          path = {
            type  = "PathPrefix"
            value = path
          }
        }]
        backendRefs = [{
          name = kubernetes_service_v1.proxy.metadata[0].name
          port = 80
        }]
      }]
    }
  }
}
