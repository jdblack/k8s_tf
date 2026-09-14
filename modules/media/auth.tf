# Authentik proxy outpost in front of the media apps (sonarr/radarr/prowlarr/
# bazarr/qbittorrent). Lives in the media module, not the auth stack, because it
# protects media apps and runs in this namespace (authentik chart 2025.10.x no
# longer embeds proxy outposts, so Terraform owns the outpost Deployment).
#
# Traffic: browser -> media gateway (TLS) -> this outpost (:9000) -> app svc.
locals {
  # Service every arr HTTPRoute (each app module's route.tf) and the outpost
  # module below must agree on.
  auth_outpost_service = "authentik-outpost"

  # Bookmark-tile icons from the dashboard-icons set via jsDelivr: versionless
  # CDN URLs that don't depend on each app's own web assets or on the app being
  # reachable. File is "<slug>.svg" (all five match their slug).
  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"

  # Proxy applications in authentik. external_host is the public URL (what the
  # gateway serves); internal_host is the app's in-cluster Service. The port
  # varies: the *arr charts serve on :80, the hand-rolled qbittorrent web UI on
  # :8080. Keep in sync with arr_stack.tf.
  #
  # qbittorrent's torrent port (21010) is NOT here -- peer traffic stays direct
  # on its own LoadBalancer Service, never behind the outpost.
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
# group (its bindings gate who can reach the apps; membership is hand-managed in
# the authentik UI), and the shared proxy outpost.
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
