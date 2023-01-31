module "ssl_cert" {
  source = "../../../common/server_cert"
  namespace = var.namespace
  name = "openvpn-cert"
  cert_domains = [var.domain ]
  issuer = var.cert_issuer
}

