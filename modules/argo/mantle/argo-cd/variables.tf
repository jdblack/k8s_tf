
variable oauth2_server { default = "auth.vn.linuxguru.net" } 
variable namespace   { type = string }
variable name        { default = "argo-cd" }
variable deploy_key  { type = string }
variable repo        { type = string } 

variable domain {}
variable cert_issuer { type = string }


locals {
  fqdn = "${var.name}.${var.domain}"
}
