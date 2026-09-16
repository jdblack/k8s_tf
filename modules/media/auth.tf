# authentik proxy outpost for the arr apps + qbittorrent: browser -> media gateway -> this outpost
# (:9000) -> app Service.
locals {
  # Must match every arr route and the outpost module.
  auth_outpost_service = "authentik-outpost"

  # Versionless CDN URLs: independent of the app's own assets.
  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"

  # external_host = public URL, internal_host = in-cluster Service; ports differ (arr :80, qbittorrent
  # :8080) and torrent traffic never comes through here.
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

# Proxy providers + applications per app, the "media" group, and the outpost that fronts them here.
# Its egress policy is stated in egress.tf rather than in the module: proxy_outpost is shared with
# harbor and the seaweedfs admin UI, and those namespaces have not been through this yet.
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

# The outpost moved into the `auth` module above in an ordinary apply; the `moved` blocks that carried
# its state across have since been dropped, so a future move of this shape needs them again: a
# whole-module `moved` is refused when the destination already holds resources, and OpenTofu destroys instead.
