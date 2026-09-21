module "wireguard" {
  source = "../../modules/network/wireguard"

  namespace          = "kube-network-vpn"
  external_address   = var.deployment.network.vpn.external_address
  dns                = var.deployment.network.vpn.dns
  dns_search_domains = var.deployment.network.vpn.dns_search_domains
  peers              = var.deployment.network.vpn.peers

  depends_on = [module.network]
}
