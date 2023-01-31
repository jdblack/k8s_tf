module "ssl_cert" {
  source = "../../../common/server_cert"
  namespace = var.namespace
  name = local.lb_cert
  cert_domains = [ local.fqdn, var.name ]
  issuer = var.cert_issuer
}

