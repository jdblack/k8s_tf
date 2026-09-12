module "media" {
  source           = "../../modules/media"
  namespace        = "media"
  domain           = var.deployment.common.domain
  cert_authorities = var.deployment.cert_authorities
  domains          = var.deployment.domains
  plex_claim       = try(var.deployment.media.plex_claim, "")

  # MetalLB IP the home router port-forwards qbittorrent torrent traffic to;
  # pinned so the webui/torrent Service split can't reassign it.
  qbittorrent_torrent_lb_ip = try(var.deployment.media.qbittorrent_torrent_lb_ip, null)
}
