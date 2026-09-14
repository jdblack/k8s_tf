locals {
  # Issuer per app: every media host runs on the public issuer (letsencrypt,
  # DNS-01). None of them is verified in-cluster, so nothing needs
  # ~/.ssl/ca.crt. var.cert_issuers overrides individual apps -- see
  # ../cert_manager/README.md.
  issuers = merge(
    { for app in ["sonarr", "radarr", "prowlarr", "bazarr", "qbittorrent"] : app => var.cert_authorities["public"] },
    var.cert_issuers,
  )
}

module "radarr" {
  source            = "./radarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.issuers["radarr"]
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "sonarr" {
  source            = "./sonarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.issuers["sonarr"]
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "prowlarr" {
  source            = "./prowlarr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = local.issuers["prowlarr"]
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "bazarr" {
  source            = "./bazarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.issuers["bazarr"]
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
}

module "qbittorrent" {
  source            = "./qbittorrent"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.issuers["qbittorrent"]
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
  auth_backend      = local.auth_outpost_service
  torrent_lb_ip     = var.qbittorrent_torrent_lb_ip
}
