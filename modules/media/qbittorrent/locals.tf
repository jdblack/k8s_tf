locals {
  svc_name = coalesce(var.svc_name, "${var.name}-svc")
  fqdn = "${var.name}.${var.domain}"
  issuer = var.cert_issuer
  app_data_name  = "${var.name}-data"
}
