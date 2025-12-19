variable namespace { default = "media" }
variable cert_issuer { type = string }
variable ingress_class { type = string } 
variable domain { type = string }

variable name { default = "dispatcharr" }
variable svc_name { default = "" }

locals {
  svc_name = coalesce(var.svc_name, "${var.name}-svc")
  fqdn = "${var.name}.${var.domain}"
  issuer = var.cert_issuer
  volume_name  = "${var.name}-data"
}
