locals {
  app_data_name = "${var.name}-data"
  fqdn          = "${var.name}.${var.domain}"
  cert_name     = "cert-${var.name}.${var.domain}"
}

