locals {
  # admin.<release>.<domain>; the outpost owns this host.
  host = var.admin_host != null ? var.admin_host : "admin.${var.app_name}.${var.domain}"
}

# authentik: proxy provider + application for the admin UI, the outpost that fronts it
# (Deployment/Service/Secret + core egress, co-located in this namespace) and its token.
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

# The outpost moved into the `auth` module above; these blocks carry its state across
# (drop them once the move has been applied). A whole-module `moved` cannot do this: the
# destination module already holds resources, so OpenTofu refuses the module-level mapping
# ("could not move ... existing objects already at the intended addresses") and destroys.
moved {
  from = module.outpost.kubernetes_secret_v1.api
  to   = module.auth.kubernetes_secret_v1.api
}
moved {
  from = module.outpost.kubernetes_deployment_v1.outpost
  to   = module.auth.kubernetes_deployment_v1.outpost
}
moved {
  from = module.outpost.kubernetes_service_v1.outpost
  to   = module.auth.kubernetes_service_v1.outpost
}

# Listener + HTTPRoute to the OUTPOST, not the admin Service. The names carry those of
# core's retired expose_admin, so the cert and grants are re-owned here.
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
