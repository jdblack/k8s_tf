# The A record that makes vaultwarden.linuxguru.net resolve to the PRIVATE
# gateway. Without it the *.linuxguru.net wildcard sends clients to the WAN IP
# (public gateway), which has no listener for this host.
#
# Terraform-managed and authoritative -- external-dns cannot do it, because it
# is authoritative for vn.linuxguru.net only. See
# ../network/dns/route53_record/README.md.
module "dns" {
  source = "../network/dns/route53_record"

  zone_id = var.zone_id
  name    = local.fqdn
  type    = "A"
  ttl     = 60
  records = [var.private_gateway_ip]
}
