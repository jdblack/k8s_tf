# Publishes an app through a gateway: an HTTPS ListenerSet (+ grants and cert) and,
# when backend_name is set, an HTTPRoute to it. Chart-rendered routes (harbor /
# authentik / argo-cd) leave backend_name empty and get the listener alone.

locals {
  fqdn = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"

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