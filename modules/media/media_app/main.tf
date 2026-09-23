locals {
  # Don't clobber a caller-supplied service block.
  port_pin = {
    for key, pin in {
      service = contains(keys(var.helm_values), "service") ? null : { port = var.port }
    } : key => pin if pin != null
  }

  helm_values = merge(var.helm_values, local.port_pin)

  gated        = var.auth_outpost != null
  backend_name = coalesce(try(var.auth_outpost.service, null), var.backend_name, var.name)
  backend_port = coalesce(try(var.auth_outpost.port, null), var.port)
}

resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]
}

module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  backend_name = local.backend_name
  backend_port = local.backend_port
  route_name   = local.gated ? "${var.name}-auth" : null
}

module "authentik_app" {
  count  = local.gated ? 1 : 0
  source = "../../auth/authentik/proxy_app"

  name                  = var.name
  namespace             = var.namespace
  domain                = var.domain
  outpost_id            = var.auth_outpost.outpost_id
  group_id              = var.auth_outpost.group_id
  port                  = var.port
  icon                  = var.icon
  access_token_validity = var.auth_outpost.access_token_validity
}
