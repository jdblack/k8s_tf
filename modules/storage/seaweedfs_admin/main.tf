locals {
  host = var.admin_host != null ? var.admin_host : "admin.${var.app_name}.${var.domain}"
}

module "auth" {
  source = "../../auth/authentik/proxy_outpost"

  apps = {
    "seaweedfs-admin" = {
      external_host = "https://${local.host}"
      internal_host = "http://${var.admin_service}.${var.namespace}.svc.cluster.local:${var.admin_port}"
      icon          = var.icon
    }
  }

  outpost_name   = var.outpost_name
  group_name     = var.group_name
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
