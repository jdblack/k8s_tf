locals {
  svc_name    = coalesce(var.svc_name, "${var.name}-svc")
  fqdn        = "${var.name}.${var.domain}"
  issuer      = var.cert_issuer
  volume_name = "${var.name}-data"
}
