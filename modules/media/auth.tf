# authentik proxy outpost for the arr apps + qbittorrent: browser -> media gateway ->
# this outpost (:9000) -> app Service.
locals {
  # Must match every arr route and the outpost module.
  auth_outpost_service = "authentik-outpost"

  # Versionless CDN URLs: independent of the app's own assets.
  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"

  # external_host = public URL, internal_host = in-cluster Service. Ports differ (arr :80,
  # qbittorrent :8080); torrent traffic (21010) never comes through here.
  auth_apps = {
    for app, port in {
      sonarr      = 80
      radarr      = 80
      prowlarr    = 80
      bazarr      = 80
      qbittorrent = 8080
    } :
    app => {
      external_host = "https://${app}.${var.domain}"
      internal_host = "http://${app}.${var.namespace}.svc.cluster.local:${port}"
      icon          = "${local.icon_cdn}/${app}.svg"
    }
  }
}

# Proxy providers + applications per app, the "media" group, and the outpost (Deployment/
# Service/Secret + core egress) that fronts them in this namespace.
module "auth" {
  source         = "../auth/authentik/proxy_outpost"
  apps           = local.auth_apps
  outpost_name   = "media-proxy"
  group_name     = "media"
  namespace      = var.namespace
  service_name   = local.auth_outpost_service
  domain         = var.domain
  core_namespace = var.auth_namespace

  depends_on = [kubernetes_namespace_v1.namespace]
}

# The outpost moved into the `auth` module above; these blocks carry its state across
# (drop them once the move has been applied). A whole-module `moved` cannot do this: the
# destination module already holds resources, so OpenTofu refuses the module-level mapping
# ("could not move ... existing objects already at the intended addresses") and destroys.
moved {
  from = module.auth_outpost.kubernetes_secret_v1.api
  to   = module.auth.kubernetes_secret_v1.api
}
moved {
  from = module.auth_outpost.kubernetes_deployment_v1.outpost
  to   = module.auth.kubernetes_deployment_v1.outpost
}
moved {
  from = module.auth_outpost.kubernetes_service_v1.outpost
  to   = module.auth.kubernetes_service_v1.outpost
}
moved {
  from = module.auth_outpost.module.core_egress
  to   = module.auth.module.core_egress
}
