locals {
  fqdn = "${var.hostname}.${var.domain}"

  labels = {
    "app.kubernetes.io/name" = var.name
  }

  data_pvc_name = "${var.name}-data"
}
