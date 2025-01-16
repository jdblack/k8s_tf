
variable deployment { type = map}
variable harbor { type = map }

module network {
  source = "../../core_modules/network"
  deployment = var.deployment
}

module storage {
  source = "../../core_modules/storage"
  namespace = "kube-storage"
  depends_on = [ module.network ]
}

module cert_man {
  source = "../../core_modules/cert_manager"
  data = var.deployment.cert
  depends_on = [ module.network ]
}



module dyndns {
  source = "../../service_modules/dyndns"
  namespace = "kube-network"

  registry = "${module.harbor.registry_host}/linuxguru"

  domain = "home.linuxguru.net"
  r53_zone = var.deployment.dyndns_host.R53_ZONEID

  AWS_REGION = var.deployment.dyndns_host.AWS_REGION
  AWS_ACCESS_KEY_ID = var.deployment.dyndns_host.AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY = var.deployment.dyndns_host.AWS_SECRET_ACCESS_KEY

  depends_on = [ module.harbor ]
}


module argocd {
  source = "../../core_modules/argocd"
  domain = var.deployment.common.domain
  ssl_ca = var.deployment.cert.cert_issuer
  devops_deploy_repo = var.deployment.argocd_devops.deploy_repo
  devops_deploy_key = var.deployment.argocd_devops.deploy_key
}


module harbor {
  source = "../../core_modules/harbor" 
  certca = var.deployment.cert.cert_issuer
  domain = var.deployment.common.domain
  projects = var.harbor.projects
}


