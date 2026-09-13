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

  # TEMPORARY (2026-09-14): first-account bootstrap. vaultwarden cannot create a
  # user from the CLI, so signups are open just long enough to register in the
  # web vault. FLIP THIS BACK TO false (or delete the line) once registered --
  # the host is LAN/WireGuard-only, but while it is true anyone on the LAN can
  # create an account.
  signups_allowed = true
}
