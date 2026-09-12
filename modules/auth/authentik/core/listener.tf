# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute
# is rendered by the authentik chart itself (server.route.main), so this module
# only declares the ListenerSet (which provisions the linuxguru-ca cert); the
# listener_set submodule creates the cross-namespace ReferenceGrants for both
# ListenerSet and HTTPRoute attachment.
module "expose" {
  source    = "../../../network/gateway/expose"
  name      = local.listener_name
  namespace = var.namespace
  domain    = var.domain
  # Pin the listener hostname to the route hostname so they can never silently
  # diverge: var.fqdn (auth.<domain>) wins when set, otherwise fall back to the
  # <name>.<domain> default.
  hostname          = var.fqdn != "" ? var.fqdn : null
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# The HTTPRoute is rendered by the authentik chart (server.route.main), so no
# backend_* here -- the listener is all this module declares.
moved {
  from = module.listener_set
  to   = module.expose.module.listener_set
}
