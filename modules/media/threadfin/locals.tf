locals {
  svc_name    = coalesce(var.svc_name, "${var.name}-svc")
  volume_name = "${var.name}-data"
  fqdn        = "${var.name}.${var.domain}"
}

