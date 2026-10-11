locals {
  fqdn = "${var.name}.${var.domain}"

  labels = {
    "app.kubernetes.io/name" = var.name
  }
}
