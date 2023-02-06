
terraform {
  required_version =  "~> 1.3"
}

module "openvpn" {
  source = "./modules/openvpn"
  namespace = "openvpn"
  name = "openvpn-linuxguru"
  domain = var.deployment.openvpn.domain
  cert_issuer = var.deployment.cert.cert_issuer
  registry_info = var.deployment.registry
}

# Monitoring
module "prometheus" {
  source = "./modules/prometheus"
  name = "grafana"
  namespace = "monitoring"
  cert_issuer = var.deployment.cert.cert_issuer
  domain = var.deployment.common.domain
  keycloak_realm = var.deployment.keycloak.realm
  keycloak_domain = data.kubernetes_secret.keycloak_secrets.data.site
}


module "cinc" {
  namespace = "cinc"
  source = "./modules/cinc"
  name = "cinc"
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
  registry_info = var.deployment.registry
}

module keycloak {
  source = "./modules/keycloak"
  credentials = var.deployment.keycloak.credentials
  namespace = var.deployment.keycloak.namespace
}

module ldap {
  source = "./modules/ldap"
  cert_issuer = var.deployment.cert.cert_issuer
  ldap_org= "linuxguru"
  ldap_domain = "vn.linuxguru.net"
}
