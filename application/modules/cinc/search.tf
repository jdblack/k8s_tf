module "search" {
  name = "search"
  namespace = var.namespace
  source = "../../../common/opensearch/"
  cert_issuer = var.cert_issuer
  domain = local.search_fqdn
  singlenode = true
  TLSforLB = false
  #tag = "1"
}

