module "search" {
  name = "search"
  namespace = var.namespace
  source = "../../../common/opensearch/"
  cert_issuer = var.cert_issuer
  domain = local.search_fqdn
  replicas = 2
  TLSforLB = false
  #tag = "1"
}

