
resource kubernetes_namespace auth {
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

#module keycloak_setup {
#  source = "../../main_build/keycloak"
#  realm = "linuxguru"
#  realm_display = "Linuxguru.net"
#  admin_user = module.keycloak.admin_user
#  admin_pass = module.keycloak.admin_pass
#  admin_url = module.keycloak.url
#
#}


output keycloak_admin_pass {
  value = module.keycloak.admin_pass
  sensitive= true 
}

