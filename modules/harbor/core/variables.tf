
variable namespace {  }
variable name      { default     = "harbor" }
variable domain    { type = string }
variable cert_issuer    { type = string } 
variable auth_secret { }

locals {
  ca_secret_name = "${var.cert_issuer}-cert"
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
}
