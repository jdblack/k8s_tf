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
