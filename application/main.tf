
terraform {
  required_version =  "~> 1.3"
}

module "openvpn" {
  source = "./modules/openvpn"
  namespace = "openvpn"
  name = "linuxguru"
  domain = var.deployment.openvpn.domain
  cert_issuer = var.deployment.cert.cert_issuer
  registry_info = var.deployment.registry
}

# Monitoring
module "prometheus" {
  source = "./modules/prometheus"
  namespace = "monitoring"
  cert_issuer = var.deployment.cert.cert_issuer
  domain = "grafana.${var.deployment.common.domain}"
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

