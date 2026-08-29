
variable domain {}
variable name { default="harbor" }
variable cert_issuer {}
variable oauth2_server {}


locals {
  fqdn = "${var.name}.${var.domain}"
}

