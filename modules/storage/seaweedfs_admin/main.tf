locals {
  host = var.admin_host != null ? var.admin_host : "admin.${var.app_name}.${var.domain}"
}

module "authentik_app" {
  source = "../../auth/authentik/proxy_app"

  name         = "seaweedfs-admin"
  group_prefix = "seaweedfs"
  namespace    = var.namespace
  domain       = var.domain
  hostname     = local.host
  service      = var.admin_service
  port         = var.admin_port
  icon         = var.icon
  outpost_id   = module.auth.outpost_id
}

module "auth" {
  source = "../../auth/authentik/proxy_outpost"

  outpost_name   = var.outpost_name
  namespace      = var.namespace
  service_name   = var.outpost_service
  domain         = var.domain
  core_namespace = var.auth_namespace
}

module "expose" {
  source = "../../network/gateway/expose"

  name              = "${var.app_name}-admin"
  namespace         = var.namespace
  domain            = var.domain
  hostname          = local.host
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.outpost_service
  backend_port      = 9000
}
