module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # Ungated: the route goes straight at the app, which does its own authentication.
  backend_name = local.server_name
  backend_port = local.server_port
}
