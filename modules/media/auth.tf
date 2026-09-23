locals {
  auth_service = "authentik-outpost"
  auth_port    = 9000

  # Session lifetime of every gated app here; the outpost sizes its cookie TTL from it.
  access_token_validity = "days=7"

  auth_outpost = {
    outpost_id            = module.auth.outpost_id
    group_id              = module.auth.group_id
    service               = local.auth_service
    port                  = local.auth_port
    access_token_validity = local.access_token_validity
  }
}

module "auth" {
  source = "../auth/authentik/proxy_outpost"

  outpost_name   = "media-proxy"
  group_name     = "media"
  namespace      = var.namespace
  service_name   = local.auth_service
  http_port      = local.auth_port
  domain         = var.domain
  core_namespace = var.auth_namespace

  session_validity = local.access_token_validity
}
