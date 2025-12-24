
resource kubernetes_namespace_v1 auth {
  metadata {
    name = "kube-auth"
  }
}


module keycloak {
  source = "../modules/auth/keycloak"
  namespace = "kube-auth"
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
  depends_on = [ module.cert_man, module.storage, kubernetes_namespace.auth ]
}

module authentik {
  source = "../modules/auth/authentik"
  namespace = "kube-auth"
  domain = var.deployment.common.domain
  fqdn = "auth.${var.deployment.common.domain}"
  cert_issuer = var.deployment.cert.cert_issuer
  depends_on = [ module.cert_man, module.storage, kubernetes_namespace.auth ]

}

output keycloak_admin_pass {
  value = module.keycloak.admin_pass
  sensitive= true 
}

