module "radarr" {
  source            = "./radarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "sonarr" {
  source            = "./sonarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "prowlarr" {
  source            = "./prowlarr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "bazarr" {
  source            = "./bazarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "qbittorrent" {
  source            = "./qbittorrent"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
  torrent_lb_ip     = var.qbittorrent_torrent_lb_ip
}

module "seerr" {
  source            = "./seerr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "suggestarr" {
  source            = "./suggestarr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
  pod_cidr          = var.pod_cidr
  host_cidr         = var.host_cidr
}

module "unpackerr" {
  source         = "./unpackerr"
  namespace      = var.namespace
  movies_pvc     = var.movies_pvc
  sonarr_api_key = var.sonarr_api_key
  radarr_api_key = var.radarr_api_key
}
