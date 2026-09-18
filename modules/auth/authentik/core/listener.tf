module "expose" {
  source            = "../../../network/gateway/expose"
  name              = local.listener_name
  namespace         = var.namespace
  domain            = var.domain
  hostname          = var.fqdn != "" ? var.fqdn : null
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
