
module "network" {
  source         = "../../modules/network"
  internal_dns   = var.deployment.internal_dns
  metal_networks = var.deployment.metal.networks
}

module "storage" {
  source    = "../../modules/storage"
  namespace = "kube-storage"
  # storage_nodes = var.deployment.storage.nodes   # openebs
  depends_on = [module.network]
}

module "cert_man" {
  source     = "../../modules/cert_manager"
  data       = var.deployment.cert
  acme_email = var.deployment.cert.acme_email

  # cert-manager gateway-shim (config.enableGatewayAPI) needs the Gateway API
  # CRDs to exist before it starts, so apply the gateway module first. This
  # guarantees a fresh rebuild provisions the shim before the Gateway exists.
  depends_on = [module.gateway]
}

# Gateway API (NGINX Gateway Fabric). Pilot scope: replace the media-private
# ingress controller. The Gateway data plane takes 192.168.0.106 (the old
# media-private LB IP), so existing DNS records keep working unchanged.
# Generic shared infrastructure only - each media app declares its own HTTPS
# listener (ListenerSet), Certificate, and HTTPRoute in its own module.
module "gateway" {
  source = "../../modules/network/gateway"
  domain = var.deployment.common.domain
}



#module dyndns {
#  source = "../../modules/network/dyndns"
#  namespace = "kube-network"
#
#  registry = "${module.harbor.registry_host}/library"
#
#  domain = "home.linuxguru.net"
#  r53_zone = var.deployment.dyndns_host.R53_ZONEID
#
#  AWS_REGION = var.deployment.dyndns_host.AWS_REGION
#  AWS_ACCESS_KEY_ID = var.deployment.dyndns_host.AWS_ACCESS_KEY_ID
#  AWS_SECRET_ACCESS_KEY = var.deployment.dyndns_host.AWS_SECRET_ACCESS_KEY
#
#  depends_on = [ module.harbor, module.network ]
#}
