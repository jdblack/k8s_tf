module "media" {
  source      = "../../modules/media"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer
  domains     = var.deployment.cluster.domains
  plex_claim  = try(var.deployment.media.plex_claim, "")

  pod_cidr  = var.deployment.network.pod_cidr
  host_cidr = var.deployment.network.host_cidr

  qbittorrent_torrent_lb_ip = try(var.deployment.media.qbittorrent_torrent_lb_ip, null)

  sonarr_api_key = try(var.deployment.media.sonarr_api_key, "")
  radarr_api_key = try(var.deployment.media.radarr_api_key, "")
}
