module "onlyoffice" {
  source = "./onlyoffice"

  namespace   = kubernetes_namespace_v1.namespace.metadata[0].name
  domain      = var.domain
  cert_issuer = var.cert_issuer

  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # The namespace has to exist before the deployment, claim and policies land in it.
  depends_on = [kubernetes_namespace_v1.namespace]
}
