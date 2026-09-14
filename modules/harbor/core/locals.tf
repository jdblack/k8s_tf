locals {
  fqdn = "${var.name}.${var.domain}"
  url  = "https://${local.fqdn}"
}
