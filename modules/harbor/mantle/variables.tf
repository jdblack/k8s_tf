
variable domain {}
variable name { default="harbor" }
variable cert_issuer {}
variable oauth2_server { default = "auth.vn.linuxguru.net" } 


locals {
  fqdn = "${var.name}.${var.domain}"
}

