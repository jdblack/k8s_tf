locals {
  cert_path = "/usr/share/opensearch/config/tls"
}

resource "random_password" "open_pass" {
  length = 16
  special = false
}

module "opensearch-cert" {
  source = "../server_cert"
  namespace = var.namespace
  name = "opensearch-${local.name}"
  cert_domains = [local.fqdn, local.name]
  issuer = var.cert_issuer
  encoding = "PKCS8"
}
