# Vaultwarden: a Bitwarden-compatible server for the LAN + WireGuard, on the
# shared PRIVATE gateway (`vaultwarden.linuxguru.net`). See
# modules/vaultwarden/README.md.
#
# Two deliberate deviations from the other private-gateway apps, both explained
# in that README: the cert issuer is the PUBLIC one (letsencrypt -- DNS-01, so
# an unreachable host still validates, and phones need no private CA), and the A
# record is managed here because external-dns owns vn.linuxguru.net only, while
# the linuxguru.net wildcard points at the WAN IP.
module "vaultwarden" {
  source = "../../modules/vaultwarden"

  namespace   = "vaultwarden"
  domain      = var.deployment.domains.public
  cert_issuer = var.deployment.cert_authorities.public

  # Literal zone id: the deployment's AWS key is denied route53:GetHostedZone,
  # so the record cannot look the zone up by name.
  zone_id            = var.deployment.cert.R53_ZONEID
  private_gateway_ip = var.deployment.network_ingress.private_ip

  # Pinned; there is no CI that resolves ":latest" here.
  image_tag = "1.37.3"
}
