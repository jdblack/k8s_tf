
variable namespace { default     = "harbor" }
variable name      { default     = "harbor" }
variable domain    { type = string }
variable projects  { type = map    }
variable certca    { type = string } 

locals {
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
}
