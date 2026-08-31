locals {
  fqdn      = "${var.name}.${var.domain}"
  cert_name = "cert-${var.name}.${var.domain}"
}

# App HTTPS listener on this Gateway instance (e.g. media-private).
# cert-manager gateway-shim auto-provisions the certificate secret based on the annotation.
resource "kubernetes_manifest" "listener_set" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = var.name
      namespace = var.namespace
      annotations = {
        "cert-manager.io/cluster-issuer" = var.cert_issuer
      }
    }
    spec = {
      parentRef = {
        name      = var.gateway_name
        namespace = var.gateway_namespace
      }
      listeners = [{
        name     = var.name
        port     = var.port
        protocol = var.protocol
        hostname = local.fqdn
        tls = {
          mode = "Terminate"
          certificateRefs = [
            { name = local.cert_name }
          ]
        }
      }]
    }
  }
}
