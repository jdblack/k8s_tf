
variable deployment { type = map}

module network {
  source = "../modules/network"
  deployment = var.deployment
}

module storage {
  source = "../modules/storage"
  namespace = "kube-storage"
  # storage_nodes = var.deployment.storage.nodes   # openebs
  depends_on = [ module.network ]
}

module cert_man {
  source = "../modules/cert_manager"
  data = var.deployment.cert
}



module dyndns {
  source = "../modules/network/dyndns"
  namespace = "kube-network"

  registry = "${module.harbor.registry_host}/library"

  domain = "home.linuxguru.net"
  r53_zone = var.deployment.dyndns_host.R53_ZONEID

  AWS_REGION = var.deployment.dyndns_host.AWS_REGION
  AWS_ACCESS_KEY_ID = var.deployment.dyndns_host.AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY = var.deployment.dyndns_host.AWS_SECRET_ACCESS_KEY

  depends_on = [ module.harbor, module.network ]
}
