locals {
  private_issuer = var.cert_authorities["private"]
}

module "radarr" {
  source            = "./radarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "sonarr" {
  source            = "./sonarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "prowlarr" {
  source            = "./prowlarr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "bazarr" {
  source            = "./bazarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "qbittorrent" {
  source            = "./qbittorrent"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
  torrent_lb_ip     = var.qbittorrent_torrent_lb_ip
}
