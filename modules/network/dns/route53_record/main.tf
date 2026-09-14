# A single, Terraform-authoritative Route53 record. This is DNS targeting: the
# linuxguru.net wildcard points at the WAN IP (the PUBLIC gateway), so a host
# served by the PRIVATE gateway needs its own record -- otherwise LAN clients
# follow the wildcard to the internet, hairpin back, and die on `unrecognized
# name`.
#
# external-dns cannot help: it runs the rfc2136 provider with
# domainFilters = ["vn.linuxguru.net"], so it ignores linuxguru.net hostnames.
#
# Deliberately NO `data "aws_route53_zone"`: it calls route53:GetHostedZone,
# which the lg-route53 key is explicitly denied. The caller passes the literal
# zone id (var.deployment.cert.R53_ZONEID).
resource "aws_route53_record" "this" {
  zone_id         = var.zone_id
  name            = var.name
  type            = var.type
  ttl             = var.ttl
  records         = var.records
  allow_overwrite = var.allow_overwrite
}
