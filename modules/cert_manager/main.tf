resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "release" {
  name      = "cert-manager"
  namespace = var.namespace

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set = [
    {
      name  = "installCRDs"
      value = true
    },
    {
      # Enable cert-manager's gateway-shim so it auto-provisions per-listener
      # Certificates for annotated Gateways and ListenerSets.
      name  = "config.enableGatewayAPI"
      value = true
    },
    {
      name  = "config.enableGatewayAPIListenerSet"
      value = true
    },
    {
      name  = "config.gatewayAPI.enabled"
      value = true
    },
    {
      name  = "config.gatewayAPI.enableListenerSet"
      value = true
    }
  ]
  depends_on = [kubernetes_secret_v1.ca-key]
}

