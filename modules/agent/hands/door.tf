# The doorbell. No path matcher: the door serves /hands/<key>, /activity/<name> and /healthz, so the
# whole hostname belongs to it — and a matcher is exactly the thing that silently 404s a path you
# forgot (it did, twice, on the hand-rolled route).
module "door" {
  source = "../../network/gateway/expose"
  count  = var.expose ? 1 : 0

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  hostname          = local.fqdn
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.name
  backend_port      = 80
}
