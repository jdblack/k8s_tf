
module "network" {
  source         = "../../modules/network"
  internal_dns   = var.deployment.internal_dns
  metal_networks = var.deployment.metal.networks
  gateway_ips = {
    public  = var.deployment.network_ingress.public_ip
    private = var.deployment.network_ingress.private_ip
  }
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

  # cert-manager gateway-shim (config.enableGatewayAPI) needs the Gateway API
  # CRDs to exist before it starts. modules/network/api_gateway_config.tf
  # installs them (cluster-scoped, exactly once), so wait for the network
  # module. This guarantees a fresh rebuild provisions the shim before any
  # Gateway manifests are applied.
  depends_on = [module.network]
}
