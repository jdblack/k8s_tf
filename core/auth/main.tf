resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}


module ldap {
  source = "../../common/ldap"
  cert_issuer = var.cert_issuer
  ldap_domain = var.domain
  namespace = var.namespace
}
