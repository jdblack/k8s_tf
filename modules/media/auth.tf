locals {
  auth_outpost_service = "authentik-outpost"

  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg"

  auth_apps = {
    for app, port in {
      sonarr      = 80
      radarr      = 80
      prowlarr    = 80
      bazarr      = 80
      qbittorrent = 8080
      suggestarr  = 5000
    } :
    app => {
      external_host = "https://${app}.${var.domain}"
      internal_host = "http://${app}.${var.namespace}.svc.cluster.local:${port}"
      icon          = lookup(local.auth_icon_overrides, app, "${local.icon_cdn}/${app}.svg")
    }
  }

  auth_icon_overrides = {
    suggestarr = null
  }
}

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
