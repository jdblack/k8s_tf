module "wireguard" {
  source = "../../modules/network/wireguard"

  namespace          = "kube-network-vpn"
  external_address   = var.deployment.vpn.external_address
  dns                = var.deployment.vpn.dns
  dns_search_domains = var.deployment.vpn.dns_search_domains
  peers              = var.deployment.vpn.peers

  depends_on = [module.network]
}
