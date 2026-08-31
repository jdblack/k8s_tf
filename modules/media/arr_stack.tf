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
}

module "tdarr" {
  count      = 0
  source     = "./tdarr"
  namespace  = var.namespace
  domain     = var.domain
  movies_pvc = var.movies_pvc
}

module "sonarr" {
  source            = "./sonarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "prowlarr" {
  source            = "./prowlarr"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "bazarr" {
  count             = 0
  source            = "./bazarr"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "qbittorrent" {
  source            = "./qbittorrent"
  namespace         = var.namespace
  domain            = var.domain
  movies_pvc        = var.movies_pvc
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "threadfin" {
  count             = 0
  source            = "./threadfin"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = local.private_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.namespace
}

module "dispatcharr" {
  count     = 0
  source    = "./dispatcharr"
  namespace = var.namespace
  domain    = var.domain
}
