# The A record that makes the host resolve to the PRIVATE gateway -- without it the
# *.linuxguru.net wildcard sends clients to the WAN IP, which has no listener here.
# Managed by hand because external-dns is authoritative for vn.linuxguru.net only.
module "dns" {
  source = "../network/dns/route53_record"

  zone_id = var.zone_id
  name    = local.fqdn
  type    = "A"
  ttl     = 60
  records = [var.private_gateway_ip]
}
