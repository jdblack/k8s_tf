module "typingmind" {
  source = "./typingmind"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = local.connector

  domain      = var.domain
  cert_issuer = var.cert_issuer

  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  auth_token = var.auth_token

  # The namespace has to exist before the app's Secret, Service and policies land in it.
  depends_on = [kubernetes_namespace_v1.namespace]
}
