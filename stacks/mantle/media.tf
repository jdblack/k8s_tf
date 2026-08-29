module media {
  source = "../../modules/media"
  namespace = "media"
  domain = var.deployment.common.domain
  cert_authorities = var.deployment.cert_authorities
  domains = var.deployment.domains
  plex_claim = try(var.deployment.media.plex_claim, "")
}
