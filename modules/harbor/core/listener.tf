# HTTPS listener via the shared private gateway. The HTTPRoute is rendered by the harbor chart itself
# (`expose.type = "route"`), so this module only declares the ListenerSet -- the submodule creates the
# cross-namespace ReferenceGrants for both attachments.
module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
