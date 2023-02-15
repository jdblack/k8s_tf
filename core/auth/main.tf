resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}


module ldap {
  source = "./ldap"
  cert_issuer = var.cert_issuer
  ldap_domain = var.domain
  namespace = var.namespace
  ldap_org = var.ldap_org
  ldap_dn = var.ldap_dn
}

module keycloak {
  source = "./key_cloak"
  namespace = var.namespace
  tld = var.domain
  cert_issuer = var.cert_issuer
  ingress_class = "private"
}
