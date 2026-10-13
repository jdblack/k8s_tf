module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  hostname          = local.fqdn
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # The chart's HTTP Service, not a hand-written one.
  backend_name = local.http_service_name
  backend_port = var.port
}
