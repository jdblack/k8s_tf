module "network" {
  source         = "../../modules/network"
  internal_dns   = var.deployment.internal_dns
  metal_networks = var.deployment.metal.networks
}

module "storage" {
  source     = "../../modules/storage"
  namespace  = "kube-storage"
  depends_on = [module.network]
}

module "cert_man" {
  source     = "../../modules/cert_manager"
  data       = var.deployment.cert
  acme_email = var.deployment.cert.acme_email

  depends_on = [module.network]
}
