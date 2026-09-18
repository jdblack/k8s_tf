resource "aws_route53_record" "this" {
  zone_id         = var.zone_id
  name            = var.name
  type            = var.type
  ttl             = var.ttl
  records         = var.records
  allow_overwrite = var.allow_overwrite
}
