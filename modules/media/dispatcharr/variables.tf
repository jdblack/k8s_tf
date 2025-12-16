variable namespace { default = "media" }
variable "cert_issuers" { type = map(string) }
variable domain { type = string }
variable name { default = "dispatcharr" }
variable visibility { default = "private"}

locals {
  sub = var.visibility == "private" ? ".vn" : ""
  fqdn = "${var.name}${local.sub}.${var.domain}"
  issuer = var.cert_issuers[var.visibility]

  volume_name  = "${var.name}-data"
}
