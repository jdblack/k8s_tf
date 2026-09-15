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

# Proxy providers + applications per app, the "media" group, and the shared outpost.
module "auth" {
  source       = "../auth/authentik/proxy_app"
  apps         = local.auth_apps
  outpost_name = "media-proxy"
  group_name   = "media"
}

module "auth_outpost" {
  source       = "../auth/authentik/outpost"
  namespace    = var.namespace
  outpost_name = "media-proxy"
  service_name = local.auth_outpost_service
  core_url     = "http://authentik-server.${var.auth_namespace}.svc.cluster.local:80"
  browser_url  = "https://auth.${var.domain}"
  token        = module.auth.outpost_token

  depends_on = [kubernetes_namespace_v1.namespace]
}
