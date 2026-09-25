# authentik refuses to create an outpost without providers, so the provider and its
# application are created first and the outpost is built around the provider. The
# group binding therefore lives here: its group only exists once the outpost does.
module "authentik_app" {
  source = "../../auth/authentik/proxy_app"

  name      = var.name
  namespace = var.namespace
  domain    = var.domain
  service   = var.service
  port      = var.port

  attach = false
  bind   = false
}

module "auth" {
  source = "../../auth/authentik/proxy_outpost"

  outpost_name   = var.outpost_name
  group_name     = var.group_name
  namespace      = var.namespace
  service_name   = var.outpost_service
  domain         = var.domain
  core_namespace = var.auth_namespace

  provider_ids = [module.authentik_app.app.provider_id]
}

resource "authentik_policy_binding" "access" {
  target = module.authentik_app.app.application_uuid
  group  = module.auth.group_id
  order  = 0
}

module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.outpost_service
  backend_port      = var.http_port
}
