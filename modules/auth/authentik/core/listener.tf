# HTTPS listener via the shared private gateway. The HTTPRoute is rendered by the
# authentik chart itself (server.route.main), so this declares only the ListenerSet; the
# submodule creates the ReferenceGrants for both attachments.
module "expose" {
  source    = "../../../network/gateway/expose"
  name      = local.listener_name
  namespace = var.namespace
  domain    = var.domain
  # Pinned to the route hostname so the two cannot diverge: var.fqdn (auth.<domain>) wins
  # when set, else the <name>.<domain> default.
  hostname          = var.fqdn != "" ? var.fqdn : null
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# No backend_* here: the chart renders the route itself.
