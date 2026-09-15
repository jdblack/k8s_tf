# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute is
# rendered by the authentik chart itself (server.route.main), so this module
# declares only the ListenerSet; the submodule creates the cross-namespace
# ReferenceGrants for both ListenerSet and HTTPRoute attachment.
module "expose" {
  source    = "../../../network/gateway/expose"
  name      = local.listener_name
  namespace = var.namespace
  domain    = var.domain
  # Pin the listener hostname to the route hostname so they cannot silently
  # diverge: var.fqdn (auth.<domain>) wins when set, else the <name>.<domain> default.
  hostname          = var.fqdn != "" ? var.fqdn : null
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# No backend_* here: the chart renders the route itself.
