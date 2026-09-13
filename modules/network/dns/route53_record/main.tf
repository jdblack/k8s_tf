# A single, Terraform-authoritative Route53 record.
#
# This is DNS *targeting*, not gateway trickery. The linuxguru.net wildcard
# points at the WAN IP and therefore at the PUBLIC gateway, so any host served
# by the PRIVATE gateway needs its own record -- otherwise LAN clients follow
# the wildcard out to the internet, hairpin back to the public gateway, and die
# on `unrecognized name` because no listener exists for the host there.
#
# It also exists because external-dns cannot help: it runs the rfc2136 provider
# against bind9 with domainFilters = ["vn.linuxguru.net"], so it ignores
# annotations on linuxguru.net hostnames entirely.
#
# There is deliberately NO `data "aws_route53_zone"` here: it calls
# route53:GetHostedZone, which the deployment's key (lg-route53) is explicitly
# denied. The caller passes the literal zone id instead
# (var.deployment.cert.R53_ZONEID).
resource "aws_route53_record" "this" {
  zone_id         = var.zone_id
  name            = var.name
  type            = var.type
  ttl             = var.ttl
  records         = var.records
  allow_overwrite = var.allow_overwrite
}
