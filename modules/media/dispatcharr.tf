

module dispatcharr {
  source = "./dispatcharr"
  namespace = var.namespace
  ingress_class = local.private_ingress_name
  cert_issuer = local.local_issuer
  domain = "vn.linuxguru.net"
}

