# One Terraform-authoritative Route53 record. The linuxguru.net wildcard points at the WAN IP (the
# PUBLIC gateway), so a host served by the PRIVATE gateway needs its own or LAN clients follow the
# wildcard and die on `unrecognized name`. No zone `data` source: it calls route53:GetHostedZone,
# which the deployment key is denied -- the caller passes the literal zone id.
resource "aws_route53_record" "this" {
  zone_id         = var.zone_id
  name            = var.name
  type            = var.type
  ttl             = var.ttl
  records         = var.records
  allow_overwrite = var.allow_overwrite
}
