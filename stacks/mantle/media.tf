module "media" {
  source      = "../../modules/media"
  domain      = var.deployment.common.domain
  cert_issuer = var.deployment.cert_authorities.default
  domains     = var.deployment.domains
  plex_claim  = try(var.deployment.media.plex_claim, "")

  pod_cidr  = var.deployment.network.pod_cidr
  host_cidr = var.deployment.network.host_cidr

  qbittorrent_torrent_lb_ip = try(var.deployment.media.qbittorrent_torrent_lb_ip, null)

  sonarr_api_key = try(var.deployment.media.sonarr_api_key, "")
  radarr_api_key = try(var.deployment.media.radarr_api_key, "")
}
