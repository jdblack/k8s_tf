module "expose" {
  source = "../network/gateway/expose"

  name              = var.name
  namespace         = kubernetes_namespace_v1.this.metadata[0].name
  domain            = var.domain
  hostname          = local.fqdn
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # Ungated: the route goes straight at the app, which authenticates itself against authentik.
  backend_name = var.name
  backend_port = local.app_port
}
