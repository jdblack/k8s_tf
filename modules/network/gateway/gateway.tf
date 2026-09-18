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
