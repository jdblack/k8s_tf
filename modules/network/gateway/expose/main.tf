# `expose` -- one call to publish an app through a gateway: an HTTPS
# ListenerSet (+ the cross-namespace ReferenceGrants and cert) and, optionally,
# an HTTPRoute to its backend.
#
# This is just the common pairing of ../listener_set + ../http_route (they are
# always used together) behind a single call. Apps whose CHART renders its own
# HTTPRoute (harbor / authentik / argo-cd) leave `backend_name` empty and get a
# listener only -- which still provisions the cert and the grants.
#
# It is a thin wrapper (no resources of its own), so migrating a caller is a
# `moved` block per old module (see the callers) -- no destroy/create.

locals {
  # The listener's FQDN; the route must use the SAME host (defaulting off the
  # route name would give "sonarr-auth.<domain>" instead of "sonarr.<domain>").
  fqdn = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"

  # Empty backend_name = chart-rendered route: listener only.
  with_route = var.backend_name != ""
}

module "listener_set" {
  source = "../listener_set"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  hostname          = var.hostname
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  port              = var.port
  protocol          = var.protocol
}

module "http_route" {
  count  = local.with_route ? 1 : 0
  source = "../http_route"

  name         = var.route_name != null ? var.route_name : var.name
  namespace    = var.namespace
  domain       = var.domain
  hostname     = local.fqdn
  parent_kind  = "ListenerSet"
  parent_name  = var.name
  backend_name = var.backend_name
  backend_port = var.backend_port
  annotations  = var.annotations
}