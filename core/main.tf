

module network {
  source = "./network"
  deployment = var.deployment
  namespace = "kube-network"
}

module cert_man {
  source = "./cert_man"
  issuer_name  = var.deployment.cert.cert_issuer
}

module registry {
  source = "./registry"
  namespace = var.deployment.registry.namespace
  depends_on = [ module.cert_man ]
  tld = var.deployment.common.domain
  cert_issuer = module.cert_man.issuer
  secret_name = var.deployment.registry.secret_name
}

module openebs {
  source = "./open_ebs"
}

module keycloak {
  source = "./key_cloak"
  tld = var.deployment.common.domain
  cert_issuer = module.cert_man.issuer
}

