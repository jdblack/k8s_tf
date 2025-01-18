
variable namespace {  }
variable name      { default     = "harbor" }
variable domain    { type = string }
variable certca    { type = string } 
variable auth_secret { }

locals {
  fqdn = "${var.name}.${var.domain}"
  url = "https://${local.fqdn}"
}
