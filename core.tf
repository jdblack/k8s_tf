
variable deployment { type = map}

module network {
  source = "../../core_modules/network"
  deployment = var.deployment
}

module storage {
  source = "../../core_modules/storage"
  namespace = "kube-storage"
}

module cert_man {
  source = "../../core_modules/cert_manager"
  data = var.deployment.cert
}



module registry {
  source = "../../core_modules/registry"
  namespace = var.deployment.registry.namespace
  depends_on = [ module.cert_man ]
  tld = var.deployment.common.domain
  cert_issuer = module.cert_man.issuer
  secret_name = var.deployment.registry.secret_name
}

module dyndns {
  source = "../../service_modules/dyndns"
  namespace = "kube-network"
  deployment = var.deployment
  depends_on = [ module.registry ]
}

output "registry_password" {
  value = module.registry.password
  sensitive=true
}


module misc {
  source = "../../core_modules/metrics_server"
}

