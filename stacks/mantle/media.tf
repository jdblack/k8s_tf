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

  # The local LAN: the only non-pod source allowed to reach media's
  # LoadBalancers (plex / qbittorrent-torrent / media-private gateway). Comes
  # from tfvars so renumbering the LAN is a one-line change, not a code edit.
  lan_cidrs = [var.deployment.metal.local_lan]

  # Cluster pod + service CIDRs, from tfvars (deployment.network) -- excluded
  # from the public-internet ingress peer so no cluster pod can reach media.
  cluster_cidrs = [
    var.deployment.network.pod_cidr,
    var.deployment.network.service_cidr,
  ]
}
