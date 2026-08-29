locals {
  ca_secret_name = "${var.cert_issuer}-cert"
  fqdn           = "${var.name}.${var.domain}"
  url            = "https://${local.fqdn}"
}
