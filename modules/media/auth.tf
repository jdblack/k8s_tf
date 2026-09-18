locals {
  auth_service = "authentik-outpost"
  auth_port    = 9000

  auth_outpost = {
    outpost_id = module.auth.outpost_id
    group_id   = module.auth.group_id
    service    = local.auth_service
    port       = local.auth_port
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
}
