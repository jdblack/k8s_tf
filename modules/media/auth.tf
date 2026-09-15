# Authentik proxy outpost in front of the arr apps + qbittorrent. Owned here, not
# by the auth stack, because it protects media apps and runs in this namespace
# (authentik chart 2025.10.x no longer embeds proxy outposts).
#
# Traffic: browser -> media gateway (TLS) -> this outpost (:9000) -> app svc.
locals {
  # Every arr HTTPRoute (each app module's route.tf) and the outpost module must
  # agree on this name.
  auth_outpost_service = "authentik-outpost"

  # Bookmark-tile icons from the dashboard-icons set: versionless CDN URLs, so they
  # don't depend on the app's own web assets or on the app being reachable.
  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"

  # external_host is the public URL (what the gateway serves); internal_host is the
  # app's in-cluster Service. Ports differ (arr charts :80, hand-rolled qbittorrent
  # :8080) -- keep in sync with arr_stack.tf.
  #
  # qbittorrent's torrent port (21010) is NOT here: peer traffic stays direct on its
  # own LoadBalancer Service, never behind the outpost.
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

# authentik objects: proxy providers + applications per app, the "media" access
# group (bindings gate who can reach the apps; membership is hand-managed in the
# authentik UI), and the shared proxy outpost.
module "auth" {
  source       = "../auth/authentik/proxy_app"
  apps         = local.auth_apps
  outpost_name = "media-proxy"
  group_name   = "media"
}

# The outpost's Kubernetes deployment/service in this namespace.
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
