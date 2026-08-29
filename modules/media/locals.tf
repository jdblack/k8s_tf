locals {
  private_ingress_name = "${var.namespace}-private"
  local_issuer = var.cert_authorities["private"]
}