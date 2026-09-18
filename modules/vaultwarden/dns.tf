module "dns" {
  source = "../network/dns/route53_record"

  zone_id = var.zone_id
  name    = local.fqdn
  type    = "A"
  ttl     = 60
  records = [var.private_gateway_ip]
}
