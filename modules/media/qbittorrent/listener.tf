module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  backend_name = coalesce(try(var.auth_outpost.service, null), var.name)
  backend_port = coalesce(try(var.auth_outpost.port, null), var.web_port)
  route_name   = local.gated ? "${var.name}-auth" : null
}

module "authentik_app" {
  count  = local.gated ? 1 : 0
  source = "../../auth/authentik/proxy_app"

  name                  = var.name
  namespace             = var.namespace
  domain                = var.domain
  outpost_id            = var.auth_outpost.outpost_id
  port                  = var.web_port
  icon                  = var.icon
  access_token_validity = var.auth_outpost.access_token_validity
}
