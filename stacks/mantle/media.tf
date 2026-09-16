module "media" {
  source      = "../../modules/media"
  domain      = var.deployment.common.domain
  cert_issuer = var.deployment.cert_authorities.default
  domains     = var.deployment.domains
  # Optional Plex registration token; empty in tfvars today.
  plex_claim = try(var.deployment.media.plex_claim, "")

  # LAN / cluster-CIDR / LoadBalancer inputs come from tfvars, so renumbering is a tfvars
  # edit.
  #
  # qbittorrent_torrent_lb_ip exists to re-pin the torrent LoadBalancer -- the one address
  # the home router port-forwards, so the one DNS cannot cover. Unset = float.
  qbittorrent_torrent_lb_ip = try(var.deployment.media.qbittorrent_torrent_lb_ip, null)
}
