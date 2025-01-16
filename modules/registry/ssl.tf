
module "ssl_cert" {
  source = "../cert_manager/server_cert/"
  namespace = var.namespace
  name = "${var.name}-cert"
  cert_domains = [local.fqdn, var.name]
  issuer = var.cert_issuer
  depends_on = [  kubernetes_namespace.namespace ] 
}

