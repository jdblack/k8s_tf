module "auth" {
  source = "../../auth/authentik/proxy_outpost"

  apps = {
    whisker = {
      external_host = "https://whisker.${var.domain}"
      internal_host = "http://${var.whisker_service}.${var.namespace}.svc.cluster.local:${var.whisker_port}"
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
  source = "../gateway/expose"

  name              = "whisker"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = var.outpost_service
  backend_port      = 9000
}
