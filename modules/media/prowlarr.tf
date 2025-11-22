
module prowlarr {
  source = "./prowlarr"
  namespace = var.namespace
  cert_issuers = var.cert_authorities
}
