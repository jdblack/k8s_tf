
resource kubernetes_namespace auth {
  metadata {
    name = "auth"
  }
}

module keycloak {
  source = "../../core_modules/auth/keycloak"
  namespace = "auth"
  depends_on = [ module.network ]
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
}

module keycloak_setup {
  source = "../../main_build/keycloak"
  realm = "linuxguru"
  realm_display = "Linuxguru.net"
  admin_user = module.keycloak.admin_user
  admin_pass = module.keycloak.admin_pass
  admin_url = module.keycloak.url

}


output keycloak_admin_pass {
  value = module.keycloak.admin_pass
  sensitive= true 
}

